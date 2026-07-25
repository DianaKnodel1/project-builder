import type { PortalThemeId } from "@/lib/portal-themes";

/** Kleine Wireframe-Vorschau der Portal-Designs für die Auswahl im Landing-Generator. */
export default function PortalThemePreview({ id }: { id: PortalThemeId }) {
  const base = "h-20 w-full rounded-md overflow-hidden border border-border flex";

  if (id === "split") {
    return (
      <div className={`${base} bg-background`}>
        <div className="w-1/2 bg-muted/60 border-r border-border p-2">
          <div className="h-2 w-8 rounded bg-primary/40" />
          <div className="mt-3 h-1.5 w-14 rounded bg-foreground/30" />
          <div className="mt-1 h-1.5 w-10 rounded bg-foreground/20" />
        </div>
        <div className="w-1/2 flex items-center justify-center p-2">
          <div className="w-full rounded border border-border bg-card p-1.5 space-y-1">
            <div className="h-1.5 w-10 rounded bg-foreground/40" />
            <div className="h-2 w-full rounded bg-muted" />
            <div className="h-2 w-full rounded bg-primary/70" />
          </div>
        </div>
      </div>
    );
  }

  if (id === "image") {
    return (
      <div className={`${base} bg-gradient-to-br from-slate-500 to-slate-800 items-center justify-center p-2 relative`}>
        <div className="absolute top-1.5 left-1.5 h-2 w-8 rounded bg-white/70" />
        <div className="w-3/4 rounded-lg border border-white/50 bg-white/90 p-2 space-y-1 shadow">
          <div className="h-1.5 w-10 rounded bg-slate-500/60" />
          <div className="h-2 w-full rounded bg-slate-200" />
          <div className="h-2 w-full rounded bg-slate-200" />
          <div className="h-2 w-full rounded bg-slate-700" />
        </div>
      </div>
    );
  }

  if (id === "soft") {
    return (
      <div className={`${base} bg-gradient-to-br from-primary/20 via-background to-muted items-center justify-center p-2`}>
        <div className="w-3/4 rounded-xl border border-border/60 bg-card/90 p-2 space-y-1 shadow">
          <div className="h-2 w-8 rounded bg-primary/50 mx-auto" />
          <div className="h-2 w-full rounded-lg bg-muted" />
          <div className="h-2 w-full rounded-lg bg-muted" />
          <div className="h-2.5 w-full rounded-lg bg-primary/70" />
        </div>
      </div>
    );
  }

  return (
    <div className={`${base} bg-muted/40 items-center justify-center p-2 relative`}>
      <div className="absolute top-1.5 left-1.5 h-2 w-8 rounded bg-primary/40" />
      <div className="w-3/4 rounded border border-border bg-card p-2 space-y-1">
        <div className="h-2 w-full rounded bg-muted" />
        <div className="h-2 w-full rounded bg-muted" />
        <div className="h-2 w-full rounded bg-primary/70" />
      </div>
    </div>
  );
}
