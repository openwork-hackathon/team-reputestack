import "./globals.css";

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
      <body>{children}</body>
    </html>
  );
}
