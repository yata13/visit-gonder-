import * as React from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

interface State {
  error: Error | null;
}

export class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  State
> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error("Unhandled UI error:", error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-8 text-center">
          <AlertTriangle className="h-12 w-12 text-destructive" />
          <h1 className="text-xl font-semibold">Something went wrong</h1>
          <p className="max-w-md break-words text-sm text-muted-foreground">
            {this.state.error.message}
          </p>
          <Button onClick={() => window.location.reload()}>Reload the page</Button>
        </div>
      );
    }
    return this.props.children;
  }
}
