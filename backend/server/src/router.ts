import { Request, Response, Router } from "express";
import { Database } from "./database";
import { Storage } from "./storage/storage.js";
import { Auth } from "./auth.js";

export function router(auth: Auth, database: Database, storage: Storage): Router {
  const router = Router();

  router.get('/', async (req: Request, res: Response) => {
    try {
      return res.json({
        "hello": 123,
        "db": await database.getDatabaseName(),
      });
    } catch (e) {
      return res.sendStatus(500);
    }
  });

  return router;
}
