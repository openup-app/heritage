import { Request, Response, Router } from "express";
import { Database, Person, Profile, genderSchema, ownershipUnableReasonSchema, relationshipSchema } from "./database.js";
import { Storage } from "./storage/storage.js";
import { Auth } from "./auth.js";
import { z } from "zod";
import formidable, { IncomingForm } from "formidable";
import fs from "fs/promises";
import shortUUID from "short-uuid";
import { parse } from "path";

export function router(auth: Auth, database: Database, storage: Storage): Router {
  const router = Router();

  router.post('/accounts/authenticate/send_sms', async (req: Request, res: Response) => {
    let body: SendSmsBody;
    try {
      body = sendSmsSchema.parse(req.body);
    } catch {
      return res.sendStatus(400);
    }

    const result = await auth.sendSmsCode(body.phoneNumber);
    if (result === "success") {
      return res.sendStatus(200);
    } else {
      return res.status(400).json({ "error": { "code": result } });
    }
  });

  async function signIn(credential: Credential): Promise<SignInResult> {
    if (credential.type === "oauth") {
      const googleUser = await auth.authenticateGoogleIdToken(credential.idToken);
      if (!googleUser) {
        return { "type": "badCredential" };
      }
      const signIn = await auth.getSignInTokenByEmail(googleUser.email);
      return {
        type: "success",
        uid: signIn?.uid,
        token: signIn?.token,
        data: {
          type: credential.type,
          googleUser: googleUser,
        }
      }
    } else if (credential.type === "phone") {
      const status = await auth.verifySmsCode(credential.phoneNumber, credential.smsCode);
      if (status !== "success") {
        return { "type": "badCredential" };
      }
      const signIn = await auth.getSignInTokenByPhoneNumber(credential.phoneNumber);
      return {
        type: "success",
        uid: signIn?.uid,
        token: signIn?.token,
        data: {
          type: credential.type,
          phoneNumber: credential.phoneNumber,
        }
      }
    } else {
      return { type: "failure" };
    }
  }

  async function createUser(uid: string, data: SignInData): Promise<string | undefined> {
    if (data.type === "oauth") {
      return await auth.createGoogleUser(uid, data.googleUser);
    } else if (data.type === "phone") {
      return await auth.createPhoneUser(uid, data.phoneNumber);
    }
  }

  router.post('/accounts/authenticate', async (req: Request, res: Response) => {
    let body: AuthenticateBody;
    try {
      body = authenticateSchema.parse(req.body);
    } catch {
      return res.status(400).json({ "error": { "code": "badRequest" } });
    }

    const signInResult = await signIn(body.credential);
    if (signInResult.type !== "success") {
      return res.status(400).json({ "error": { "code": signInResult.type } });
    } else {
      if (signInResult.uid && body.claimUid && signInResult.uid !== body.claimUid) {
        return res.status(400).json({ "error": { "code": "credentialUsedForDifferentUid" } });
      }

      if (signInResult.token) {
        return res.json({ "token": signInResult.token });
      }

      if (!body.claimUid) {
        return res.status(400).json({ "error": { "code": "noAccount" } });
      }

      // Ensure person exists and is unowned
      try {
        const person = await database.getPerson(body.claimUid);
        if (person.ownership === "owned") {
          return res.status(400).json({ "error": { "code": "alreadyOwned" } });
        }
      } catch (e) {
        return res.status(400).json({ "error": { "code": "unknownUid" } });
      }

      const signInToken = await createUser(body.claimUid, signInResult.data);
      if (!signInToken) {
        return res.sendStatus(500);
      }
      try {
        await database.updateOwned(body.claimUid);
      } catch {
        // Can ignore for now, but should mark as owned
      }
      return res.json({ "token": signInToken })
    }
  });

  router.post('/people/:sourceId/connections', async (req: Request, res: Response) => {
    const sourceId = req.params.sourceId;
    const creatorId = req.headers["x-app-uid"] as string | undefined;

    if (!creatorId) {
      return res.sendStatus(400);
    }

    let body: AddConnectionBody;
    try {
      body = addConnectionSchema.parse(req.body);
    } catch (e) {
      return res.sendStatus(400);
    }

    try {
      const result = await database.addConnection(sourceId, body.relationship, body.inviteText, creatorId);
      if (!result) {
        return res.sendStatus(400);
      }
      return res.json({
        'id': result.id,
        'people': result.people.map(e => constructPerson(e, storage)),
      });
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.post('/people', async (req: Request, res: Response) => {
    let body: CreateRootBody;
    try {
      body = createRootSchema.parse(req.body);
    } catch (e) {
      return res.sendStatus(400);
    }

    try {
      const person = await database.createRootPerson(body.firstName, body.lastName);
      return res.json({
        'person': constructPerson(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/people/:id/graph', async (req: Request, res: Response) => {
    const id = req.params.id;
    try {
      const people = await database.getLimitedGraph(id);
      return res.json({
        'people': people.map(e => constructPerson(e, storage)),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/people/:id', async (req: Request, res: Response) => {
    const id = req.params.id;
    try {
      const person = await database.getPerson(id);
      return res.json({
        'person': constructPerson(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put('/people/:id/profile', async (req: Request, res: Response) => {
    const id = req.params.id;

    try {
      const { fields, files } = await parseForm(req);
      const normalized = normalizeFields(fields);
      const profileUpdate = profileUpdateSchema.parse(normalized.profile);

      const currentProfile = (await database.getPerson(id)).profile;

      let updatedPhotoKey: string | null | undefined;
      if (profileUpdate.photo.type === "memory") {
        const photoFiles = files.photo;
        const photoFile = photoFiles && photoFiles.length !== 0 ? photoFiles[0] : undefined;
        if (photoFile) {
          updatedPhotoKey = await uploadImage(photoFile, storage);
          const currentPhotoKey = currentProfile.photoKey;
          if (currentPhotoKey) {
            await storage.delete(currentPhotoKey);
          }
        }
      } else if (profileUpdate.photo.type === "network" && profileUpdate.photo.key === "public/no_image.png") {
        updatedPhotoKey = null;
        const currentPhotoKey = currentProfile.photoKey;
        if (currentPhotoKey) {
          await storage.delete(currentPhotoKey);
        }
      }

      let updatedGalleryKeys = profileUpdate.gallery.map(e => e.key);
      const galleryFiles = Array.isArray(files.gallery) ? files.gallery : [];
      updatedGalleryKeys = await updateGallery(currentProfile.galleryKeys, profileUpdate.gallery, galleryFiles, storage);

      const updatedProfile = applyProfileUpdates(currentProfile, profileUpdate, updatedPhotoKey, updatedGalleryKeys);
      const person = await database.updateProfile(id, updatedProfile);
      return res.json({
        'person': constructPerson(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.delete('/people/:id', async (req: Request, res: Response) => {
    const id = req.params.id;
    try {
      const oldPerson = await database.getPerson(id);
      const updatedPeople = await database.deletePerson(id);
      const imageKeysToDelete = [oldPerson.profile.photoKey, ...oldPerson.profile.galleryKeys];
      for (const key of imageKeysToDelete) {
        if (key) {
          await storage.delete(key);
        }
      }
      return res.json({
        'people': updatedPeople.map(p => constructPerson(p, storage)),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put("/people/:id/ownership_unable_reason", async (req: Request, res: Response) => {
    const id = req.params.id;

    let body: PutOwnershipUnableReasonBody;
    try {
      body = putOwnershipUnableReasonSchema.parse(req.body);
    } catch {
      return res.sendStatus(400);
    }

    try {
      const oldPerson = await database.getPerson(id);
      if (oldPerson.ownership === "owned") {
        return res.sendStatus(401);
      }
      const person = await database.updateOwnershipUnableReason(id, body.reason);
      return res.json({
        'person': constructPerson(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/roots', async (req: Request, res: Response) => {
    try {
      const people = await database.getRoots();
      return res.json({
        'people': people.map(e => constructPerson(e, storage)),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/invites/:inviteId', async (req: Request, res: Response) => {
    const inviteId = req.params.inviteId;
    try {
      const inviteText = await database.getInvite(inviteId);
      if (inviteText) {
        return res.json({
          inviteText: inviteText,
        });
      }
      return res.sendStatus(500);
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.post('/invites', async (req: Request, res: Response) => {
    try {
      const addInvite = addInviteSchema.parse(req.body);
      await database.addInvite(addInvite.fromId, addInvite.toId, addInvite.inviteText);
      return res.sendStatus(200);
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  return router;
}

function applyProfileUpdates(currentProfile: Profile, profileUpdate: ProfileUpdate, photoKey: string | null | undefined, galleryKeys: string[]): Profile {
  return {
    firstName: profileUpdate.firstName ?? currentProfile.firstName,
    lastName: profileUpdate.lastName ?? currentProfile.lastName,
    gender: profileUpdate.gender,
    photoKey: photoKey ?? (photoKey === null ? null : currentProfile.photoKey),
    galleryKeys: galleryKeys ?? currentProfile.galleryKeys,
    birthday: profileUpdate.birthday,
    deathday: profileUpdate.deathday,
    birthplace: profileUpdate.birthplace ?? currentProfile.birthplace,
    occupation: profileUpdate.occupation ?? currentProfile.occupation,
    hobbies: profileUpdate.hobbies ?? currentProfile.hobbies,
  }
}

async function updateGallery(oldKeys: string[], updates: GalleryUpdate[], files: formidable.File[], storage: Storage): Promise<string[]> {
  const updatedKeys: string[] = [];

  for (const update of updates) {
    if (update.type === 'network') {
      if (oldKeys.includes(update.key)) {
        updatedKeys.push(update.key);
      }
    } else if (update.type === 'memory') {
      const matchingFiles = files.filter(f => parse(f.originalFilename ?? "").name === update.key);
      const file = matchingFiles.length === 0 ? undefined : matchingFiles[0];
      if (file) {
        const newKey = await uploadImage(file, storage);
        updatedKeys.push(newKey);
      }
    }
  }

  for (const oldKey of oldKeys) {
    if (!updatedKeys.includes(oldKey)) {
      await storage.delete(oldKey);
    }
  }

  return updatedKeys;
}

async function uploadImage(file: formidable.File, storage: Storage): Promise<string> {
  const buffer = await fs.readFile(file.filepath);
  const key = `images/${shortUUID.generate()}.jpg`;
  await storage.upload(key, buffer);
  return key;
}

function constructPerson(person: Person, storage: Storage) {
  const profile: any = {
    ...person.profile
  }
  const object: any = {
    ...person,
    profile: profile
  }

  const photoKey = profile.photoKey ?? "public/no_image.png";
  profile.photo = {
    "type": "network",
    "key": photoKey,
    "url": storage.urlForKey(photoKey),
  };
  delete profile.photoKey;

  const gallery: { type: "network", "key": string, "url": string }[] = [];
  for (const key of profile.galleryKeys) {
    gallery.push({
      "type": "network",
      "key": key,
      "url": storage.urlForKey(key),
    });
  }
  profile.gallery = gallery;
  delete profile.galleryKey;
  return object;
}



function parseForm(req: Request): Promise<{ fields: formidable.Fields; files: formidable.Files }> {
  return new Promise((resolve, reject) => {
    const form = new IncomingForm({ keepExtensions: true });

    form.parse(req, (err, fields, files) => {
      if (err) {
        return reject(err);
      }
      resolve({ fields, files });
    });
  });
};

// Convert arrays to object
function normalizeFields(fields: formidable.Fields) {
  const normalized: { [key: string]: any } = {};

  for (const [key, value] of Object.entries(fields)) {
    if (Array.isArray(value)) {
      try {
        normalized[key] = JSON.parse(value[0]);
      } catch (e) {
        normalized[key] = value[0];
      }
    } else {
      normalized[key] = value;
    }
  }

  return normalized;
};

const sendSmsSchema = z.object({
  phoneNumber: z.string(),
});

const oauthCredentialSchema = z.object({
  type: z.literal("oauth"),
  idToken: z.string(),
})

const phoneCredentialSchema = z.object({
  type: z.literal("phone"),
  phoneNumber: z.string(),
  smsCode: z.string(),
});

const credentialSchema = z.discriminatedUnion("type", [oauthCredentialSchema, phoneCredentialSchema]);

const authenticateSchema = z.object({
  claimUid: z.string().nullable().optional(),
  credential: credentialSchema,
});

const addConnectionSchema = z.object({
  relationship: relationshipSchema,
  inviteText: z.string(),
});

const createRootSchema = z.object({
  firstName: z.string(),
  lastName: z.string(),
});

const putOwnershipUnableReasonSchema = z.object({
  reason: ownershipUnableReasonSchema.nullable(),
});

const photoUpdateSchema = z.object({
  type: z.enum(["network", "memory"]),
  key: z.string(),
})

const profileUpdateSchema = z.object({
  firstName: z.string(),
  lastName: z.string(),
  gender: genderSchema,
  photo: photoUpdateSchema,
  gallery: z.array(photoUpdateSchema),
  birthday: z.string().nullable(),
  deathday: z.string().nullable(),
  birthplace: z.string(),
  occupation: z.string(),
  hobbies: z.string(),
});

const addInviteSchema = z.object({
  fromId: z.string(),
  toId: z.string(),
  inviteText: z.string(),
});

type SendSmsBody = z.infer<typeof sendSmsSchema>;

type Credential = z.infer<typeof credentialSchema>;

type AuthenticateBody = z.infer<typeof authenticateSchema>;

type AddConnectionBody = z.infer<typeof addConnectionSchema>;

type CreateRootBody = z.infer<typeof createRootSchema>;

type PutOwnershipUnableReasonBody = z.infer<typeof putOwnershipUnableReasonSchema>;

type GalleryUpdate = z.infer<typeof photoUpdateSchema>;

type ProfileUpdate = z.infer<typeof profileUpdateSchema>;

const googleUserSchema = z.object({
  googleId: z.string(),
  email: z.string(),
  name: z.string().optional(),
  picture: z.string().optional(),

});

const authResultOauthDataSchema = z.object({
  type: z.literal("oauth"),
  googleUser: googleUserSchema,
});

const authResultPhoneDataSchema = z.object({
  type: z.literal("phone"),
  phoneNumber: z.string(),
});

const signInBadCredendialSchema = z.object({
  type: z.literal("badCredential"),
});

const signInAlreadyOwnedSchema = z.object({
  type: z.literal("alreadyOwned"),
});

const accountLinkFailureSchema = z.object({
  type: z.literal("accountLinkFailure"),
});

const signInFailureSchema = z.object({
  type: z.literal("failure"),
});

const signInDataSchema = z.discriminatedUnion("type", [authResultOauthDataSchema, authResultPhoneDataSchema]);

const signInResultSuccessSchema = z.object({
  type: z.literal("success"),
  uid: z.string().nullable().optional(),
  token: z.string().nullable().optional(),
  data: signInDataSchema,
});

const signInResultSchema = z.discriminatedUnion("type", [signInResultSuccessSchema, signInBadCredendialSchema, signInAlreadyOwnedSchema, accountLinkFailureSchema, signInFailureSchema]);

type SignInData = z.infer<typeof signInDataSchema>;

type SignInResult = z.infer<typeof signInResultSchema>;