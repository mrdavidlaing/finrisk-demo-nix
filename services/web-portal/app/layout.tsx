import React, { ReactNode } from 'react'
import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'TransferX - Multi-Rail Funds Transfer',
  description: 'Secure funds transfer platform with SWIFT and Crypto rails',
}

export default function RootLayout({
  children,
}: {
  children: ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}

