import express from "express";
import compression from "compression";
import logger from "./log.js";
import { router } from "./router.js";
import cors from "cors";
import { Database } from "./database.js";
import * as gcp from "gcp-metadata";
import { initFirebaseAdmin } from "./firebase.js";
import { S3Storage } from "./storage/s3.js";
import { Auth } from "./auth.js";
import { OAuth2Client } from "google-auth-library";
import Twilio from "twilio";

function getS3Storage() {
  const awsAccessKeyId = process.env.AWS_ACCESS_KEY_ID;
  const awsSecretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;
  const awsRegion = process.env.AWS_REGION;
  const mediaBucket = process.env.MEDIA_BUCKET;
  const mediaCdnPrefix = process.env.MEDIA_CDN_PREFIX;
  if (!(awsAccessKeyId && awsSecretAccessKey && awsRegion && mediaBucket && mediaCdnPrefix)) {
    throw 'Missing environment variable';
  }
  return new S3Storage({
    accessKeyId: awsAccessKeyId,
    secretAccessKey: awsSecretAccessKey,
    region: awsRegion,
    bucketName: mediaBucket,
    cdnPrefix: mediaCdnPrefix,
  });
}

async function init() {
  let projectId = process.env.GCP_PROJECT_ID;
  if (!projectId) {
    const isAvailable = await gcp.isAvailable();
    if (isAvailable) {
      projectId = await gcp.project("project-id");
    }
    if (!projectId) {
      throw "Missing Project ID";
    }
  }

  const googleClientId = process.env.GOOGLE_CLIENT_ID;
  if (!googleClientId) {
    throw "Missing Google Client ID";
  }

  const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
  const twilioServiceSid = process.env.TWILIO_SERVICE_SID;
  if (!twilioAccountSid || !twilioAuthToken || !twilioServiceSid) {
    throw `Missing Twilio environment variable`;
  }

  initFirebaseAdmin();
  const database = new Database();
  const storage = getS3Storage();
  const googleOauth = new OAuth2Client(googleClientId)
  const twilio = Twilio(twilioAccountSid, twilioAuthToken);
  const twilioServices = twilio.verify.v2.services(twilioServiceSid);
  const auth = new Auth(googleOauth, twilioServices);

  const expressApp = express();
  expressApp.use(cors());
  expressApp.use(express.json());
  expressApp.use(compression());

  expressApp.use((req, res, next) => {
    logger.info(`Request ${req.method} ${req.originalUrl} BODY: ${JSON.stringify(req.body)}`);
    next();
  });
  expressApp.use("/v1", router(auth, database, storage));

  const port = process.env.PORT || 8080;
  expressApp.listen(port, () => {
    logger.info(`Web server started on port ${port}`);
  });
}

init();
