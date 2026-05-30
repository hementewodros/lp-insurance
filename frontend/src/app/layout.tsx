import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";
import Link from "next/link";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "LiquiShield",
  description: "Liquidity Insurance Provider",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-gray-50 text-gray-900">
        <Providers>
          <nav className="border-b bg-white p-4">
            <div className="max-w-4xl mx-auto flex items-center justify-between">
              <Link href="/" className="font-bold text-xl text-blue-600">
                LiquiShield
              </Link>
              <div className="space-x-4">
                <Link href="/" className="hover:text-blue-600">Dashboard</Link>
                <Link href="/buy" className="hover:text-blue-600">Buy Insurance</Link>
                <Link href="/claim" className="hover:text-blue-600">Claim</Link>
              </div>
            </div>
          </nav>
          <main className="max-w-4xl mx-auto p-4 py-8 flex-1 w-full">
            {children}
          </main>
        </Providers>
      </body>
    </html>
  );
}
