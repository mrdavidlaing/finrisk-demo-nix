'use client'

import React from 'react'
import Link from 'next/link'

interface ServiceInfo {
  name: string
  hash: string
  path: string
}

export default function ProvenancePage() {
  const services: ServiceInfo[] = [
    { name: 'api-gateway', hash: 'sha256-abc123...', path: '/nix/store/abc123-api-gateway' },
    { name: 'kyc-service', hash: 'sha256-def456...', path: '/nix/store/def456-kyc-service' },
    { name: 'fee-service', hash: 'sha256-ghi789...', path: '/nix/store/ghi789-fee-service' },
    { name: 'sanctions-service', hash: 'sha256-jkl012...', path: '/nix/store/jkl012-sanctions-service' },
    { name: 'swift-gateway', hash: 'sha256-mno345...', path: '/nix/store/mno345-swift-gateway' },
    { name: 'crypto-transfer', hash: 'sha256-pqr678...', path: '/nix/store/pqr678-crypto-transfer' },
    { name: 'web-portal', hash: 'sha256-stu901...', path: '/nix/store/stu901-web-portal' },
  ]

  return (
    <main className="flex min-h-screen flex-col p-24">
      <div className="z-10 max-w-6xl w-full">
        <Link href="/admin" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Admin
        </Link>
        <h1 className="text-4xl font-bold mb-8 text-gray-900 dark:text-white">Build Provenance</h1>
        <p className="text-gray-600 dark:text-gray-300 mb-6">
          Nix store paths and derivation hashes proving reproducible builds
        </p>

        <div className="space-y-4">
          {services.map((service: ServiceInfo) => (
            <div key={service.name} className="bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700">
              <h2 className="text-2xl font-bold mb-2 text-gray-900 dark:text-white">{service.name}</h2>
              <div className="space-y-2">
                <p className="text-sm text-gray-700 dark:text-gray-300">
                  <strong className="text-gray-900 dark:text-white">Derivation Hash:</strong> <code className="bg-gray-100 dark:bg-neutral-700 px-2 py-1 rounded text-gray-800 dark:text-gray-200">{service.hash}</code>
                </p>
                <p className="text-sm text-gray-700 dark:text-gray-300">
                  <strong className="text-gray-900 dark:text-white">Store Path:</strong> <code className="bg-gray-100 dark:bg-neutral-700 px-2 py-1 rounded text-gray-800 dark:text-gray-200">{service.path}</code>
                </p>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Same inputs = same hash. This proves the build is reproducible.
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </main>
  )
}

