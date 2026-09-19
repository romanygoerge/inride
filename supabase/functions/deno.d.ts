// Deno and Supabase Edge Functions ambient type declarations for IDE / TypeScript Language Server

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    toObject(): Record<string, string>;
  }

  export const env: Env;

  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
    options?: {
      port?: number;
      hostname?: string;
      onListen?: (params: { port: number; hostname: string }) => void;
      onError?: (error: unknown) => Response | Promise<Response>;
    }
  ): void;
}

declare module "https://deno.land/std@0.177.0/http/server.ts" {
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
    options?: {
      port?: number;
      hostname?: string;
      onListen?: (params: { port: number; hostname: string }) => void;
      onError?: (error: unknown) => Response | Promise<Response>;
    }
  ): void;
}

declare module "https://esm.sh/@supabase/supabase-js@2.39.8" {
  export * from "@supabase/supabase-js";
}

declare module "https://*" {
  const content: any;
  export default content;
  export const serve: any;
  export const createClient: any;
}
