import { Request, Response, Router } from "express";
import { Database, genderSchema, relationshipSchema } from "./database.js";
import { Storage } from "./storage/storage.js";
import { Auth } from "./auth.js";
import { z } from "zod";
import { parse as qsParse } from "qs";

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
      const node = await database.createRootNode(body.gender);
      return res.json({
        'node': node,
      })
    } catch (e) {
      console.log(e);
      return res.sendStatus(500);
    }
  });

  router.get('/nodes', async (req: Request, res: Response) => {
    let idsQuery = req.query.ids;
    const parsedIds = typeof idsQuery === 'string'
      ? idsQuery
        .split(',')
        .map(e => e.trim())
        .filter(e => e.length !== 0)
      : [];
    const ids = [...new Set(parsedIds)];
    if (ids.length === 0) {
      return res.sendStatus(400);
    }
    try {
      const nodes = await database.getNodes(ids);
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
  gender: genderSchema
});


type AddConnectionBody = z.infer<typeof addConnectionSchema>;

type CreateRootBody = z.infer<typeof createRootSchema>;