import React from 'react'
import Link from 'next/link'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm">
        <h1 className="text-4xl font-bold mb-8 text-center text-gray-900 dark:text-white">
          TransferX Platform
        </h1>
        <p className="text-xl mb-12 text-center text-gray-600 dark:text-gray-300">
          Multi-Rail Funds Transfer Platform
        </p>
        <div className="grid grid-cols-2 gap-4">
          <Link
            href="/transfer"
            className="group rounded-lg border border-gray-200 dark:border-neutral-700 px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 dark:hover:border-neutral-600 dark:hover:bg-neutral-800/50"
          >
            <h2 className="mb-3 text-2xl font-semibold text-gray-900 dark:text-white">
              Transfer Money{' '}
              <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
                -&gt;
              </span>
            </h2>
            <p className="m-0 max-w-[30ch] text-sm text-gray-500 dark:text-gray-400">
              Send money via SWIFT or Crypto rails
            </p>
          </Link>

          <Link
            href="/admin"
            className="group rounded-lg border border-gray-200 dark:border-neutral-700 px-5 py-4 transition-colors hover:border-gray-300 hover:bg-gray-100 dark:hover:border-neutral-600 dark:hover:bg-neutral-800/50"
          >
            <h2 className="mb-3 text-2xl font-semibold text-gray-900 dark:text-white">
              Admin Dashboard{' '}
              <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
                -&gt;
              </span>
            </h2>
            <p className="m-0 max-w-[30ch] text-sm text-gray-500 dark:text-gray-400">
              View compliance, SBOMs, and vulnerabilities
            </p>
          </Link>
        </div>
      </div>
    </main>
  )
}

