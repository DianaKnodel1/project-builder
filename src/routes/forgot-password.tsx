import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/forgot-password")({
  component: ForgotPasswordPage,
});

import { useState } from "react";
import { useNavigate } from "@/lib/router-compat";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { ArrowLeft, CheckCircle2 } from "lucide-react";
import AuthShell from "@/components/auth/AuthShell";

function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const navigate = useNavigate();
  const { toast } = useToast();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;
    setLoading(true);
    // Tenant-SMTP-Versand statt Supabase-Auth-Default (eigene Domain & Reputation).
    const { error } = await supabase.functions.invoke("send-password-reset", {
      body: { email: email.trim(), host: window.location.hostname },
    });
    setLoading(false);
    if (error) {
      toast({ title: "Fehler", description: error.message, variant: "destructive" });
      return;
    }
    // Immer Erfolg anzeigen — keine User-Enumeration.
    setSent(true);
  };

  if (sent) {
    return (
      <AuthShell title="E-Mail gesendet" description="Prüfe dein Postfach.">
        <div className="space-y-5">
          <div className="flex items-start gap-3 rounded-lg border border-border bg-muted/40 p-3">
            <CheckCircle2 className="h-4 w-4 text-primary mt-0.5 shrink-0" />
            <p className="text-sm text-muted-foreground">
              Wenn ein Konto mit dieser E-Mail existiert, erhältst du einen Link zum Zurücksetzen deines
              Passworts. Der Link ist 24 Stunden gültig und nur einmal nutzbar.
            </p>
          </div>
          <Button variant="outline" className="w-full h-11 gap-2" onClick={() => navigate("/login")}>
            <ArrowLeft className="h-4 w-4" /> Zurück zum Login
          </Button>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      title="Passwort vergessen"
      description="Gib deine E-Mail ein und wir senden dir einen Link zum Zurücksetzen."
    >
      <form onSubmit={handleSubmit} className="space-y-5">
        <div className="space-y-2">
          <label htmlFor="reset-email" className="text-sm font-medium text-foreground">
            E-Mail-Adresse
          </label>
          <Input
            id="reset-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="name@unternehmen.de"
            autoComplete="email"
            className="h-11"
            required
          />
        </div>
        <Button type="submit" className="w-full h-11 text-sm font-semibold" disabled={loading}>
          {loading ? "Wird gesendet…" : "Reset-Link senden"}
        </Button>
      </form>
      <button
        onClick={() => navigate("/login")}
        className="w-full text-center text-xs text-muted-foreground hover:text-foreground transition-colors"
      >
        ← Zurück zum Login
      </button>
    </AuthShell>
  );
}

