import { getAuth, Auth as FirebaseAuth, UserRecord } from "firebase-admin/auth";
import { GoogleAuth, OAuth2Client } from "google-auth-library";

export class Auth {
    private firebaseAuth: FirebaseAuth;
    private googleOauth: OAuth2Client;

    public constructor(googleOauth: OAuth2Client) {
        this.firebaseAuth = getAuth();
        this.googleOauth = googleOauth;
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

    public async createUser(uid: string, googleUser: GoogleUser): Promise<string | undefined> {
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

    public async getSignInTokenByUid(uid: string): Promise<string | undefined> {
        try {
            const token = await this.firebaseAuth.createCustomToken(uid);
            return token;
        } catch (e) {
            return;
        }
    }
}

export type GoogleUser = {
    googleId: string,
    email: string,
    name?: string,
    picture?: string,
}