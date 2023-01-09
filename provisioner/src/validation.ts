import { z, ZodError, ZodType, ZodTypeDef } from 'zod';

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
  }
}

/**
 * Helper to validate using Zod.
 */
export const withValidation = <Input, ZodSchema extends ZodType<unknown, ZodTypeDef, unknown>>(
  validationSchema: ZodSchema,
  inputToValidate: Input,
  onValidationFailure: (
    formattedValidationMessage: string,
    validationError: ZodError<unknown>,
  ) => void,
): ZodSchema['_output'] => {
  const validatedInput = validationSchema.safeParse(inputToValidate);

  if (validatedInput.success === false) {
    const validationMessage = validatedInput.error.issues
      .map(({ path, message }) => `${path.join('.')}: ${message}`)
      .join('\n');

    onValidationFailure(validationMessage, validatedInput.error);

    return inputToValidate;
  }

  return validatedInput.data;
};

export const onValidationFailureFatal = (validationMessage: string) => {
  throw new ValidationError(`Validation failed: ${validationMessage}`);
};

/**
 * Schema for expected API Gateway event structure.
 *  - Validates our expectations of the structure
 */
export const apiGwRequestEventSchema = z.object({
  requestContext: z.object({
    timeEpoch: z.number(),
    http: z.object({
      method: z.string(),
    }),
  }),
  headers: z.record(z.string()),
  rawPath: z.string(),
  rawQueryString: z.string(),
  body: z.string(),
});

/**
 * Schema of "start" command from Control Room, version 1.
 */
export const startCommandSchemaV1 = z.object({
  runtimeLinkToken: z.string(),
  workspaceId: z.string(),
  runtimeId: z.string(),
});
