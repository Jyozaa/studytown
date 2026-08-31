import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://studytown-focus.jyoza.chatgpt.site'),
  title: 'StudyTown — A cozy focus game',
  description: 'Choose a cozy place, settle in, and focus.',
  openGraph: { title: 'StudyTown', description: 'A cozy focus game', images: [{ url: '/og.png', width: 1730, height: 909 }] },
  twitter: { card: 'summary_large_image', title: 'StudyTown', description: 'A cozy focus game', images: ['/og.png'] },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
