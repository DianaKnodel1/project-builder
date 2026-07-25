/**
 * Portal-Designs (Themes) für die Auth-Seiten des Mitarbeiter-Portals:
 * Login, Registrierung, Passwort vergessen.
 *
 * Auswahl erfolgt im Landing-Generator (nur Fast-Track) und wird am Tenant
 * gespeichert (`tenants.portal_theme`). Ohne Auswahl gilt "classic" —
 * dadurch sieht ein bestehendes Portal exakt wie bisher aus.
 */

export type PortalThemeId = "classic" | "minimal" | "split" | "soft";

export interface PortalThemeTokens {
  /** Äußerer Seitenrahmen */
  page: string;
  /** Dekoration im Hintergrund */
  decor: "waves" | "none" | "glow";
  /** Marken-Seitenpanel links (nur classic/split) */
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

const classic: PortalThemeTokens = {
  page: "min-h-screen flex bg-[#0a0d1a] text-white relative overflow-hidden",
  decor: "waves",
  brandPanel: true,
  card: "rounded-2xl border border-white/10 bg-white/[0.04] backdrop-blur-xl shadow-2xl shadow-black/40",
  cardPadding: "p-8 sm:p-10 space-y-7",
  heading: "text-3xl font-heading font-bold tracking-tight text-white",
  subText: "text-sm text-white/60 leading-relaxed",
  label: "text-sm font-medium text-white/90",
  input:
    "h-11 bg-white/5 border-white/10 text-white placeholder:text-white/30 focus-visible:ring-white/20 focus-visible:border-white/30",
  primaryButton: "w-full h-11 text-sm font-semibold bg-white text-slate-900 hover:bg-white/90 shadow-lg shadow-white/10",
  secondaryButton: "w-full h-11 text-sm font-medium border-white/15 bg-white/5 text-white hover:bg-white/10 hover:text-white",
  mutedText: "text-xs text-white/40",
  dividerLine: "w-full border-t border-white/10",
  dividerLabel: "bg-[#11141f] px-3 text-white/40",
  warnBox: "rounded-lg border border-amber-400/30 bg-amber-400/10 p-3 flex items-start gap-3",
  warnText: "text-xs text-amber-100",
  warnAction: "text-xs font-medium text-amber-200 underline hover:text-amber-100",
  errorBox: "rounded-lg border border-red-400/30 bg-red-400/10 p-3 text-sm text-red-100",
  wizardPage:
    "min-h-screen flex items-center justify-center bg-gradient-to-br from-background via-background to-muted/50 p-4 relative overflow-hidden",
  wizardCard: "w-full max-w-lg animate-fade-in shadow-2xl border-0 bg-card/95 backdrop-blur-sm relative",
};

const minimal: PortalThemeTokens = {
  page: "min-h-screen flex flex-col items-center justify-center bg-muted/40 px-4 py-10",
  decor: "none",
  brandPanel: false,
  card: "rounded-2xl border border-border bg-card shadow-sm",
  cardPadding: "p-7 sm:p-8 space-y-6",
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
  wizardPage: "min-h-screen flex items-center justify-center bg-muted/40 p-4",
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

const soft: PortalThemeTokens = {
  ...minimal,
  page: "min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-primary/10 via-background to-muted/60 px-4 py-10 relative overflow-hidden",
  decor: "glow",
  brandPanel: false,
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
    id: "classic",
    name: "Classic (Dunkel)",
    description: "Aktuelles Design: dunkler Hintergrund, Glas-Karte, Markenfläche links.",
    tokens: classic,
  },
  {
    id: "minimal",
    name: "Minimal (Hell)",
    description: "Ruhige, zentrierte Karte auf neutralem Hintergrund. Keine Effekte.",
    tokens: minimal,
  },
  {
    id: "split",
    name: "Marken-Split (Hell)",
    description: "Links Markenfläche mit Logo & Claim, rechts das Formular.",
    tokens: split,
  },
  {
    id: "soft",
    name: "Soft (Farbverlauf)",
    description: "Weiche, abgerundete Karte mit dezentem Verlauf in der Firmenfarbe.",
    tokens: soft,
  },
];

export const DEFAULT_PORTAL_THEME: PortalThemeId = "classic";

export function getPortalTheme(id?: string | null): PortalTheme {
  return PORTAL_THEMES.find((t) => t.id === id) ?? PORTAL_THEMES[0];
}
