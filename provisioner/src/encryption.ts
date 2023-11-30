import {
  CommitmentPolicy,
  RawAesKeyringNode,
  RawAesWrappingSuiteIdentifier,
  buildClient,
} from '@aws-crypto/client-node';

import crypto from 'node:crypto';

const client = buildClient(CommitmentPolicy.REQUIRE_ENCRYPT_REQUIRE_DECRYPT);

const prepareKey = (key: Buffer): Uint8Array => {
  if (key.byteLength === 32) {
    return new Uint8Array(key);
  }

  const hash = crypto.createHash('sha256');
  hash.update(key);
  const derivedKey = hash.digest();
  return new Uint8Array(derivedKey);
};

export const decryptData = async (ciphertext: Buffer, key: Buffer): Promise<Buffer> => {
  console.log(
    `Attempt to decrypt data. Ciphertext size of ${ciphertext.byteLength} bytes and key size of ${key.byteLength} bytes.`,
  );

  /**
   * These values are currently hardcoded in Control Room.
   */
  const keyName = 'on-demand-worker-secret';
  const keyNamespace = 'robocorp';

  const wrappingSuite = RawAesWrappingSuiteIdentifier.AES256_GCM_IV12_TAG16_NO_PADDING;
  const keyring = new RawAesKeyringNode({
    keyName,
    keyNamespace,
    unencryptedMasterKey: prepareKey(key),
    wrappingSuite,
  });

  const decryptionResult = await client.decrypt(keyring, ciphertext);

  console.log(
    'Decrypted payload with context information:',
    JSON.stringify(decryptionResult.messageHeader.encryptionContext),
  );

  return decryptionResult.plaintext;
};
