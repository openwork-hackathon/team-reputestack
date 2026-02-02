export const metadata = {
  title: "ReputeStack",
  description: "Portable reputation receipts for AI agents"
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "Inter, system-ui, Arial" }}>{children}</body>
    </html>
  );
}
