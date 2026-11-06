import crypto from "node:crypto";

export function hmacSha256(key, message) {
    return crypto.createHmac("sha256", key).update(message).digest("hex");
}

export function timingSafeEqualHex(a, b) {
    const ba = Buffer.from(String(a || ""), "hex");
    const bb = Buffer.from(String(b || ""), "hex");
    if (ba.length !== bb.length || ba.length === 0) return false;
    return crypto.timingSafeEqual(ba, bb);
}

export function hkdfSha256(ikm, salt, info, length = 32) {
    const key = crypto.hkdfSync(
        "sha256",
        Buffer.isBuffer(ikm) ? ikm : Buffer.from(ikm, "utf8"),
        Buffer.isBuffer(salt) ? salt : Buffer.from(salt || "", "utf8"),
        Buffer.isBuffer(info) ? info : Buffer.from(info || "", "utf8"),
        length
    );
    return Buffer.from(key);
}

export function generateX25519() {
    return crypto.generateKeyPairSync("x25519");
}

export function exportPublicKey(key) {
    return key.export({ format: "der", type: "spki" }).toString("base64");
}

export function importPublicKey(b64) {
    return crypto.createPublicKey({
        key: Buffer.from(b64, "base64"),
        format: "der",
        type: "spki",
    });
}

export function diffieHellman(privateKey, publicKey) {
    return crypto.diffieHellman({ privateKey, publicKey });
}

export function aesGcmEncrypt(key, plaintext) {
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
    const ct = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return {
        nonce_b64: nonce.toString("base64"),
        ciphertext_b64: ct.toString("base64"),
        tag_b64: cipher.getAuthTag().toString("base64"),
    };
}

export function aesGcmDecrypt(key, nonce_b64, ciphertext_b64, tag_b64) {
    const decipher = crypto.createDecipheriv(
        "aes-256-gcm",
        key,
        Buffer.from(nonce_b64, "base64")
    );
    decipher.setAuthTag(Buffer.from(tag_b64, "base64"));
    return Buffer.concat([
        decipher.update(Buffer.from(ciphertext_b64, "base64")),
        decipher.final(),
    ]);
}

export function randomHex(bytes = 16) {
    return crypto.randomBytes(bytes).toString("hex");
}

export function randomBytes(length) {
    return crypto.randomBytes(length);
}

export function deriveFallbackSessionKey(masterSecretHex, sessionId, hwid) {
    return hkdfSha256(
        Buffer.from(masterSecretHex, "hex"),
        Buffer.from(sessionId, "hex"),
        Buffer.from(`rawr-session-v2|${hwid}`, "utf8"),
        32
    );
}

export function xorBuffers(a, b) {
    if (a.length !== b.length) throw new Error("xor length mismatch");
    const out = Buffer.alloc(a.length);
    for (let i = 0; i < a.length; i++) out[i] = a[i] ^ b[i];
    return out;
}
