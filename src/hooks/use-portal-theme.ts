import { useTenant } from "@/contexts/TenantContext";
import { getPortalTheme, type PortalTheme } from "@/lib/portal-themes";

/** Aktives Portal-Design des Tenants (Fallback: classic = bisheriges Aussehen). */
export function usePortalTheme(): PortalTheme {
  const { tenant } = useTenant();
  return getPortalTheme((tenant as any)?.portal_theme ?? null);
}
