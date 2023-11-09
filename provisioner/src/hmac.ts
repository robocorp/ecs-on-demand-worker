import crypto from 'crypto';
import { z } from 'zod';
import { apiGwRequestEventSchema } from './validation';

const HMAC_DIGEST_ALGORITHM = 'sha256';
const TIMESTAMP_TOLERANCE_SECONDS = 15 * 60;

export enum HmacErrorType {
  MALFORMED_REQUEST = 'MALFORMED_REQUEST',
  NOT_AUTHENTICATED = 'NOT_AUTHENTICATED',
  INVALID_TIMESTAMP = 'INVALID_TIMESTAMP',
  EXPIRED_TIMESTAMP = 'EXPIRED_TIMESTAMP',
}

export class HmacError extends Error {
  constructor(
    message: string,
    public type: HmacErrorType,
  ) {
    super(message);
  }
}

const getHeader = (headers: Record<string, string>, requestedHeaderName: string) => {
  for (const actualHeaderName in headers) {
    if (actualHeaderName.toLowerCase() === requestedHeaderName.toLowerCase()) {
      const value = headers[actualHeaderName];
      if (value) {
        return value;
      }
    }
  }

  throw new HmacError(`Header '${requestedHeaderName}' missing`, HmacErrorType.MALFORMED_REQUEST);
};

const validateTimestamp = (currentTime: number, clientTimeStr: string): number => {
  const clientTime = Number(clientTimeStr);
  const timeDiff = Math.abs(currentTime - clientTime);
  if (Number.isNaN(timeDiff)) {
    throw new HmacError(`Invalid timestamp '${clientTimeStr}'`, HmacErrorType.INVALID_TIMESTAMP);
  }
  if (timeDiff > TIMESTAMP_TOLERANCE_SECONDS) {
    throw new HmacError(
      `Request expired, given timestamp (${clientTimeStr}) differs too much (${timeDiff} seconds) from server time (${currentTime})`,
      HmacErrorType.EXPIRED_TIMESTAMP,
    );
  }
  return timeDiff;
};

export const validateHmac = (
  request: z.infer<typeof apiGwRequestEventSchema>,
  secret: string,
): boolean => {
  const receivedSignature = getHeader(request.headers, 'x-rc-signature');
  const receivedTimestamp = getHeader(request.headers, 'x-rc-timestamp');
  const requestSignedHeaders = getHeader(request.headers, 'x-rc-signed-headers');
  const headersToSign = requestSignedHeaders.split(';');

  const headersWithValues = headersToSign
    .map((header) => `${header}:${getHeader(request.headers, header)}`)
    .join('\n');

  const bodyDigest = crypto
    .createHash(HMAC_DIGEST_ALGORITHM)
    .update(Buffer.from(request.body))
    .digest('base64');

  const requestMaterial = [
    request.requestContext.http.method.toUpperCase(),
    request.rawPath,
    request.rawQueryString,
    headersWithValues,
    requestSignedHeaders,
    bodyDigest,
  ].join('\n');

  const stringToSign = [
    HMAC_DIGEST_ALGORITHM,
    receivedTimestamp,
    crypto.createHash(HMAC_DIGEST_ALGORITHM).update(requestMaterial).digest('base64'),
  ].join('\n');

  const calculatedSignature = crypto
    .createHmac(HMAC_DIGEST_ALGORITHM, secret)
    .update(stringToSign)
    .digest('hex');

  if (calculatedSignature !== receivedSignature) {
    throw new HmacError('HMAC signature mismatch', HmacErrorType.NOT_AUTHENTICATED);
  }
  console.log('HMAC signature validation OK.');

  const timeDiff = validateTimestamp(
    Math.floor(request.requestContext.timeEpoch / 1000),
    receivedTimestamp,
  );
  console.log(`Timestamp validation OK (difference=${timeDiff} seconds).`);

  return true;
};
