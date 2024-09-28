import { Request, Response, Router } from "express";
import { Database, Person, Profile, genderSchema, profileSchema, relationshipSchema } from "./database.js";
import { Storage } from "./storage/storage.js";
import { Auth } from "./auth.js";
import { z } from "zod";
import formidable, { IncomingForm } from "formidable";
import fs from "fs/promises";
import shortUUID from "short-uuid";

export function router(auth: Auth, database: Database, storage: Storage): Router {
  const router = Router();

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
      const people = await database.addConnection(sourceId, body.name, body.gender, body.relationship, creatorId);
      return res.json({
        'people': people.map(e => constructURLs(e, storage)),
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
      const person = await database.createRootPerson(body.name, body.gender);
      return res.json({
        'person': constructURLs(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/people/:id', async (req: Request, res: Response) => {
    const id = req.params.id;
    try {
      const people = await database.getLimitedGraph(id);
      return res.json({
        'people': people.map(e => constructURLs(e, storage)),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put('/people/:id/profile', async (req: Request, res: Response) => {
    const id = req.params.id;

    let profile: Profile;
    let imageFile: formidable.File | undefined;
    try {
      const { fields, files } = await parseForm(req);
      const normalized = normalizeFields(fields);
      profile = profileSchema.parse(normalized.profile);
      const file = files.image;
      if (file) {
        imageFile = Array.isArray(file) ? file[0] : file;
      }
    } catch (e) {
      return res.sendStatus(400);
    }

    try {
      if (imageFile) {
        const buffer = await fs.readFile(imageFile.filepath);
        const oldProfile = await database.getPerson(id);
        const oldImageKey = oldProfile.profile.imageKey;
        const imageKey = `images/${shortUUID.generate()}.jpg`;
        await storage.upload(imageKey, buffer);
        if (oldImageKey) {
          await storage.delete(oldImageKey);
        }
        profile.imageKey = imageKey;
      }

      const person = await database.updateProfile(id, profile);
      return res.json({
        'person': constructURLs(person, storage),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put('/people/:id/take_ownership', async (req: Request, res: Response) => {
    const id = req.params.id;

    try {
      const person = await database.updateOwnership(id, id);
      return res.json({
        'person': constructURLs(person, storage),
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
        'people': people.map(e => constructURLs(e, storage)),
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  return router;
}

function constructURLs(person: Person, storage: Storage) {
  const object: any = {
    ...person,

  }
  const imageKey = object.profile.imageKey ?? "public/no_image.png";
  object.profile.imageUrl = storage.urlForKey(imageKey);
  return object;
}


function parseForm(req: Request): Promise<{ fields: formidable.Fields; files: formidable.Files }> {
  return new Promise((resolve, reject) => {
    const form = new IncomingForm({ uploadDir: 'uploads/', keepExtensions: true });

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


const addConnectionSchema = z.object({
  name: z.string(),
  gender: genderSchema,
  relationship: relationshipSchema,
});

const createRootSchema = z.object({
  name: z.string(),
  gender: genderSchema,
});


const updateProfileSchema = z.object({
  profile: profileSchema,
});

type AddConnectionBody = z.infer<typeof addConnectionSchema>;

type CreateRootBody = z.infer<typeof createRootSchema>;

type UpdateProfileBody = z.infer<typeof updateProfileSchema>;