import { getAuth, Auth as FirebaseAuth, UserRecord } from "firebase-admin/auth";
import { OAuth2Client } from "google-auth-library";
import { ServiceContext } from "twilio/lib/rest/verify/v2/service";

export class Auth {
    private firebaseAuth: FirebaseAuth;
    private googleOauth: OAuth2Client;
    private twilioServices: ServiceContext;

    public constructor(googleOauth: OAuth2Client, twilioServices: ServiceContext) {
        this.firebaseAuth = getAuth();
        this.googleOauth = googleOauth;
        this.twilioServices = twilioServices;
    }

    public async uidForToken(authToken: string): Promise<string | undefined> {
        try {
            const decodedToken = await this.firebaseAuth.verifyIdToken(authToken);
            return decodedToken.uid;
        } catch (e) {
            return undefined;
        }
    }

    public async isUidTokenValid(
        authToken: string,
        uid: string
    ): Promise<boolean> {
        try {
            return (await this.uidForToken(authToken)) === uid;
        } catch (e) {
            return false;
        }
    }

    public async authenticateGoogleIdToken(idToken: string): Promise<GoogleUser | undefined> {
        const ticket = await this.googleOauth.verifyIdToken({
            idToken: idToken,
            audience: this.googleOauth._clientId,
        });
        const payload = ticket.getPayload();
        const email = payload?.email;
        if (!(payload && email)) {
            return;
        }
        return {
            googleId: payload.sub,
            email: email,
            name: payload.name,
            picture: payload.picture,
        }
    }

    public async sendSmsCode(phoneNumber: string): Promise<SmsSendStatus> {
        const result = await this.twilioServices.verifications.create({ to: phoneNumber, channel: "sms" });
        return result.status as SmsSendStatus;
    }

    public async verifySmsCode(phoneNumber: string, smsCode: string): Promise<boolean> {
        const result = await this.twilioServices.verificationChecks.create({ to: phoneNumber, code: smsCode });
        return result.status === "approved";
    }

    public async createGoogleUser(uid: string, googleUser: GoogleUser): Promise<string | undefined> {
        try {
            await this.firebaseAuth.createUser({
                uid: uid,
                email: googleUser.email,
                emailVerified: true,
                providerToLink: {
                    uid: googleUser.googleId,
                    displayName: googleUser.name,
                    email: googleUser.email,
                    photoURL: googleUser.picture,
                    providerId: "google.com",
                }
            })
            return this.getSignInTokenByUid(uid)
        } catch (e) {
            return;
        }
    }

    public async createPhoneUser(uid: string, phoneNumber: string): Promise<string | undefined> {
        try {
            await this.firebaseAuth.createUser({
                uid: uid,
                phoneNumber: phoneNumber,
            });
            return this.getSignInTokenByUid(uid)
        } catch (e) {
            return;
        }
    }

    public async getSignInTokenByEmail(email: string): Promise<string | undefined> {
        try {
            const userRecord = await this.firebaseAuth.getUserByEmail(email);
            return this.getSignInTokenByUid(userRecord.uid);
        } catch (e) {
            return;
        }
    }

    public async getSignInTokenByPhoneNumber(phoneNumber: string): Promise<string | undefined> {
        try {
            const userRecord = await this.firebaseAuth.getUserByPhoneNumber(phoneNumber);
            return this.getSignInTokenByUid(userRecord.uid);
        } catch (e) {
            return;
        }
    }

    public async getSignInTokenByUid(uid: string): Promise<string | undefined> {
        try {
            const token = await this.firebaseAuth.createCustomToken(uid);
            return token;
        } catch (e) {
            return;
        }
    }
}

export type SmsSendStatus = "pending" | "approved" | "canceled" | "max_attempts_reached" | "deleted" | "failed" | "expired";

export type GoogleUser = {
    googleId: string,
    email: string,
    name?: string,
    picture?: string,
}