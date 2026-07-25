/**
 * Portal-Designs (Themes) für die Auth-Seiten des Mitarbeiter-Portals:
 * Login, Registrierung, Passwort vergessen.
 *
 * Auswahl erfolgt im Landing-Generator (nur Fast-Track) und wird am Tenant
 * gespeichert (`tenants.portal_theme`). Ohne Auswahl gilt "minimal".
 *
 * Stand 2026-07: schlichte, helle Designs. Das alte dunkle "classic"
 * (Wellen-Grafik) wurde entfernt und wird auf "minimal" gemappt.
 */

export type PortalThemeId = "minimal" | "split" | "image" | "soft";

export interface PortalThemeTokens {
  /** Äußerer Seitenrahmen */
  page: string;
  /** Dekoration im Hintergrund */
  decor: "none" | "glow" | "image";
  /** Marken-Seitenpanel links (nur split) */
  brandPanel: boolean;
  /** Karte mit dem Formular */
  card: string;
  cardPadding: string;
  heading: string;
  subText: string;
  label: string;
  input: string;
  primaryButton: string;
  secondaryButton: string;
  mutedText: string;
  dividerLine: string;
  dividerLabel: string;
  warnBox: string;
  warnText: string;
  warnAction: string;
  errorBox: string;
  /** Registrierungs-Wizard (nutzt eigene Karte) */
  wizardPage: string;
  wizardCard: string;
}

export interface PortalTheme {
  id: PortalThemeId;
  name: string;
  description: string;
  tokens: PortalThemeTokens;
}

const minimal: PortalThemeTokens = {
  page: "min-h-screen flex flex-col bg-muted/30",
  decor: "none",
  brandPanel: false,
  card: "rounded-2xl border border-border bg-card shadow-sm",
  cardPadding: "p-7 sm:p-9 space-y-6",
  heading: "text-xl font-heading font-semibold text-foreground",
  subText: "text-sm text-muted-foreground leading-relaxed",
  label: "text-sm font-medium text-foreground",
  input: "h-11",
  primaryButton: "w-full h-11 text-sm font-semibold",
  secondaryButton: "w-full h-11 text-sm font-medium",
  mutedText: "text-xs text-muted-foreground",
  dividerLine: "w-full border-t border-border",
  dividerLabel: "bg-card px-3 text-muted-foreground",
  warnBox: "rounded-lg border border-border bg-muted/50 p-3 flex items-start gap-3",
  warnText: "text-xs text-foreground",
  warnAction: "text-xs font-medium text-primary underline hover:no-underline",
  errorBox: "rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive",
  wizardPage: "min-h-screen flex items-center justify-center bg-muted/30 p-4",
  wizardCard: "w-full max-w-lg border border-border bg-card shadow-sm",
};

const split: PortalThemeTokens = {
  ...minimal,
  page: "min-h-screen flex bg-background text-foreground",
  brandPanel: true,
  card: "rounded-2xl border border-border bg-card shadow-md",
  cardPadding: "p-8 sm:p-10 space-y-6",
  heading: "text-2xl font-heading font-semibold text-foreground",
  wizardPage: "min-h-screen flex items-center justify-center bg-background p-4",
  wizardCard: "w-full max-w-lg border border-border bg-card shadow-md",
};

const image: PortalThemeTokens = {
  ...minimal,
  page: "min-h-screen flex flex-col relative overflow-hidden bg-slate-900",
  decor: "image",
  card: "rounded-2xl border border-white/40 bg-card/95 backdrop-blur-md shadow-2xl shadow-black/20",
  cardPadding: "p-7 sm:p-9 space-y-6",
  heading: "text-2xl font-heading font-semibold text-foreground",
  wizardPage: "min-h-screen flex items-center justify-center p-4 relative overflow-hidden bg-slate-900",
  wizardCard: "w-full max-w-lg rounded-2xl border border-white/40 bg-card/95 backdrop-blur-md shadow-2xl",
};

const soft: PortalThemeTokens = {
  ...minimal,
  page: "min-h-screen flex flex-col bg-gradient-to-br from-primary/10 via-background to-muted/60 relative overflow-hidden",
  decor: "glow",
  card: "rounded-3xl border border-border/60 bg-card/90 backdrop-blur-sm shadow-xl shadow-primary/5",
  cardPadding: "p-8 sm:p-10 space-y-6",
  heading: "text-2xl font-heading font-bold text-foreground",
  primaryButton: "w-full h-12 text-sm font-semibold rounded-xl",
  secondaryButton: "w-full h-12 text-sm font-medium rounded-xl",
  wizardPage:
    "min-h-screen flex items-center justify-center bg-gradient-to-br from-primary/10 via-background to-muted/60 p-4 relative overflow-hidden",
  wizardCard: "w-full max-w-lg rounded-3xl border border-border/60 bg-card/90 backdrop-blur-sm shadow-xl shadow-primary/5",
};

export const PORTAL_THEMES: PortalTheme[] = [
  {
    id: "minimal",
    name: "Minimal (Hell)",
    description: "Schlichte, zentrierte Karte auf hellem Grund. Logo oben links. Keine Effekte.",
    tokens: minimal,
  },
  {
    id: "split",
    name: "Marken-Split (Hell)",
    description: "Links Markenfläche mit Logo und kurzem Satz, rechts das Formular.",
    tokens: split,
  },
  {
    id: "image",
    name: "Theme-Bild",
    description: "Großes Hintergrundbild mit heller Karte darüber. Bild pro Tenant austauschbar.",
    tokens: image,
  },
  {
    id: "soft",
    name: "Soft (Farbverlauf)",
    description: "Weiche, abgerundete Karte auf dezentem Verlauf in der Firmenfarbe.",
    tokens: soft,
  },
];

export const DEFAULT_PORTAL_THEME: PortalThemeId = "minimal";

/** Fallback-Hintergrundbild für das Theme „Theme-Bild" (Tenant kann eigenes setzen). */
export const DEFAULT_PORTAL_BACKGROUND =
  "https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=2000&q=70";

export function getPortalTheme(id?: string | null): PortalTheme {
  // "classic" existiert nicht mehr → auf das neue Standard-Design mappen.
  const normalized = id === "classic" ? DEFAULT_PORTAL_THEME : id;
  return PORTAL_THEMES.find((t) => t.id === normalized) ?? PORTAL_THEMES[0];
}
