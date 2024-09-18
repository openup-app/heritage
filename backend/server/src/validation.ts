import { NextFunction, Request, Response } from "express";
import { header, ValidationChain, validationResult } from "express-validator";
import { Auth } from "./auth.js";

const notFoundError = "not_found";
const unauthorizedError = "unauthorized";
const serverError = "server_error";

export function respondToUnauthorizedRequests(
    req: Request,
    res: Response,
    next: NextFunction
) {
    const errors = validationResult(req);
    if (errors.isEmpty()) {
        return next();
    }

    const error = errors.array()[0].msg;
    if (error === notFoundError) {
        return res.sendStatus(404);
    } else if (error === unauthorizedError) {
        return res.sendStatus(401);
    } else if (error === serverError) {
        return res.sendStatus(500);
    } else {
        console.info(
            `Unable to handle auth error message ${JSON.stringify(errors.array())} ${req.method
            } ${req.url}`
        );
        return res.sendStatus(500);
    }
}

export function respondToInvalidRequests(
    req: Request,
    res: Response,
    next: NextFunction
) {
    const errors = validationResult(req);
    if (errors.isEmpty()) {
        return next();
    }
    return res.status(400).json({ errors: errors.array() });
}

function tokenSubstring(value: string | undefined): string {
    return value?.substring(7) ?? "";
}

export function validateAuthorizationWithParam(auth: Auth): ValidationChain {
    return header("authorization", unauthorizedError).custom(
        async (value, meta) => {
            const uid = meta.req.params?.uid;
            if (!uid) {
                return Promise.reject(unauthorizedError);
            }

            const valid = await auth.isUidTokenValid(tokenSubstring(value), uid);
            if (!valid) {
                return Promise.reject(unauthorizedError);
            }
        }
    );
}

/// Verifies that a valid ID token is provided, and sets req.body.uid to the
/// UID contained in the Auth token.
export function validateAuthorization(auth: Auth): ValidationChain {
    return header("authorization", unauthorizedError).custom(
        async (value, meta) => {
            const uid = await auth.uidForToken(tokenSubstring(value));
            if (!uid) {
                return Promise.reject();
            }
            meta.req.body.uid = uid;
            return Promise.resolve();
        }
    );
}

/// Sets req.body.uid to the UID contained in the Auth token if there is one.
export function validateAuthorizationOptional(
    auth: Auth
): ValidationChain {
    return header("authorization", unauthorizedError)
        .optional()
        .custom(async (value, meta) => {
            const uid = await auth.uidForToken(tokenSubstring(value));
            if (!uid) {
                return Promise.resolve();
            }
            meta.req.body.uid = uid;
            return Promise.resolve();
        });
}
