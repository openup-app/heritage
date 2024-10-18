import { getAuth, Auth as FirebaseAuth, UserRecord } from "firebase-admin/auth";
import { LoginTicket, OAuth2Client } from "google-auth-library";
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
        let ticket: LoginTicket;
        try {
            ticket = await this.googleOauth.verifyIdToken({
                idToken: idToken,
                audience: this.googleOauth._clientId,
            });
        } catch (e) {
            return;
        }
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

    public async sendSmsCode(phoneNumber: string): Promise<SmsStatus> {
        try {
            const result = await this.twilioServices.verifications.create({ to: phoneNumber, channel: "sms" });
            const status = result.status as TwilioSmsStatus;
            if (status === "approved" || status === "pending") {
                return "success";
            } else if (status === "max_attempts_reached") {
                return "tooManyAttempts";
            } else {
                return "failure";
            }
        } catch (e: any) {
            if (e.code == 20429) {
                return "tooManyAttempts";
            } else if (e.code === 21608) {
                return "badPhoneNumber";
            } else if (e.code === 60200) {
                return "badPhoneNumber";
            }
            console.error(JSON.stringify(e));
            return "failure";
        }
    }

    public async verifySmsCode(phoneNumber: string, smsCode: string): Promise<SmsStatus> {
        try {
            const result = await this.twilioServices.verificationChecks.create({ to: phoneNumber, code: smsCode });
            const status = result.status as TwilioSmsStatus;
            if (status === "approved" || status === "pending") {
                return "success";
            } else if (status === "max_attempts_reached") {
                return "tooManyAttempts";
            } else {
                return "failure";
            }
        } catch (e: any) {
            if (e.code == 20429) {
                return "tooManyAttempts";
            } else if (e.code === 21608) {
                return "badPhoneNumber";
            } else if (e.code === 60200) {
                return "badPhoneNumber";
            }
            console.error(JSON.stringify(e));
            return "failure";
        }

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

    public async getSignInTokenByEmail(email: string): Promise<{ uid: string, token: string } | undefined> {
        try {
            const userRecord = await this.firebaseAuth.getUserByEmail(email);
            const token = await this.getSignInTokenByUid(userRecord.uid);
            if (!token) {
                return;
            }
            return {
                uid: userRecord.uid,
                token: token,
            };
        } catch (e) {
            return;
        }
    }

    public async getSignInTokenByPhoneNumber(phoneNumber: string): Promise<{ uid: string, token: string } | undefined> {
        try {
            const userRecord = await this.firebaseAuth.getUserByPhoneNumber(phoneNumber);
            const token = await this.getSignInTokenByUid(userRecord.uid);
            if (!token) {
                return;
            }
            return {
                uid: userRecord.uid,
                token: token,
            };
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

type TwilioSmsStatus = "pending" | "approved" | "canceled" | "max_attempts_reached" | "deleted" | "failed" | "expired";

export type SmsStatus = "success" | "tooManyAttempts" | "badPhoneNumber" | "failure";

export type GoogleUser = {
    googleId: string,
    email: string,
    name?: string,
    picture?: string,
}