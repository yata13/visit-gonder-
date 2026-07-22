import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import CheckpointsTab from "./CheckpointsTab";
import StoriesTab from "./StoriesTab";
import TriviaTab from "./TriviaTab";

export default function PassportPage() {
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">Gondar Passport</h1>
        <p className="text-sm text-muted-foreground">
          Tourists scan a QR code at each checkpoint to collect points and
          unlock stories and trivia.
        </p>
      </div>

      <Tabs defaultValue="checkpoints">
        <TabsList>
          <TabsTrigger value="checkpoints">Check-in points</TabsTrigger>
          <TabsTrigger value="stories">Stories</TabsTrigger>
          <TabsTrigger value="trivia">Trivia</TabsTrigger>
        </TabsList>
        <TabsContent value="checkpoints">
          <CheckpointsTab />
        </TabsContent>
        <TabsContent value="stories">
          <StoriesTab />
        </TabsContent>
        <TabsContent value="trivia">
          <TriviaTab />
        </TabsContent>
      </Tabs>
    </div>
  );
}
