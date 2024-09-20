import { Request, Response, Router } from "express";
import { Database, Profile, genderSchema, profileSchema, relationshipSchema } from "./database.js";
import { Storage } from "./storage/storage.js";
import { Auth } from "./auth.js";
import { z } from "zod";

export function router(auth: Auth, database: Database, storage: Storage): Router {
  const router = Router();

  router.post('/nodes/:sourceId/connections', async (req: Request, res: Response) => {
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
      const nodes = await database.addConnection(sourceId, body.name, body.gender, body.relationship, creatorId);
      return res.json({
        'nodes': nodes,
      });
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.post('/nodes', async (req: Request, res: Response) => {
    let body: CreateRootBody;
    try {
      body = createRootSchema.parse(req.body);
    } catch (e) {
      return res.sendStatus(400);
    }

    try {
      const node = await database.createRootNode(body.name, body.gender);
      return res.json({
        'node': node,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/nodes/:id', async (req: Request, res: Response) => {
    const id = req.params.id;
    try {
      const nodes = await database.getLimitedGraph(id);
      return res.json({
        'nodes': nodes,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put('/nodes/:id/profile', async (req: Request, res: Response) => {
    const id = req.params.id;

    let body: UpdateProfileBody;
    try {
      body = updateProfileSchema.parse(req.body);
    } catch (e) {
      return res.sendStatus(400);
    }

    try {
      const node = await database.updateProfile(id, body.profile);
      return res.json({
        'node': node,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.put('/nodes/:id/take_ownership', async (req: Request, res: Response) => {
    const id = req.params.id;

    try {
      const node = await database.updateOwnership(id, id);
      return res.json({
        'node': node,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/roots', async (req: Request, res: Response) => {
    try {
      const nodes = await database.getRoots();
      return res.json({
        'nodes': nodes,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  return router;
}

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