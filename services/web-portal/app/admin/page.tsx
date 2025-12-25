'use client'

import React, { useEffect, useState } from 'react'
import { listSBOMs, getVulnerabilities, SBOM, Vulnerability } from '@/lib/api'
import Link from 'next/link'

export default function AdminPage() {
  const [sboms, setSboms] = useState<SBOM[]>([])
  const [vulnerabilities, setVulnerabilities] = useState<Vulnerability[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadData() {
      try {
        const [sbomsData, vulnsData] = await Promise.all([
          listSBOMs(),
          getVulnerabilities(),
        ])
        setSboms(sbomsData)
        setVulnerabilities(vulnsData)
      } catch (err) {
        console.error('Failed to load data:', err)
      } finally {
        setLoading(false)
      }
    }
    loadData()
  }, [])

  const severityColors: Record<string, string> = {
    CRITICAL: 'bg-red-600',
    HIGH: 'bg-orange-600',
    MEDIUM: 'bg-yellow-600',
    LOW: 'bg-blue-600',
  }

  return (
    <main className="flex min-h-screen flex-col p-24">
      <div className="z-10 max-w-6xl w-full">
        <Link href="/" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Home
        </Link>
        <h1 className="text-4xl font-bold mb-8 text-gray-900 dark:text-white">Admin Dashboard</h1>

        <div className="grid grid-cols-3 gap-4 mb-8">
          <Link href="/admin" className="p-4 bg-blue-100 dark:bg-blue-900/40 rounded-lg border border-blue-200 dark:border-blue-800">
            <h2 className="font-bold text-gray-900 dark:text-white">Service Health</h2>
            <p className="text-sm text-gray-600 dark:text-gray-300">View all services</p>
          </Link>
          <Link href="/admin/sboms" className="p-4 bg-green-100 dark:bg-green-900/40 rounded-lg border border-green-200 dark:border-green-800">
            <h2 className="font-bold text-gray-900 dark:text-white">SBOMs</h2>
            <p className="text-sm text-gray-600 dark:text-gray-300">{sboms.length} services</p>
          </Link>
          <Link href="/admin/vulnerabilities" className="p-4 bg-red-100 dark:bg-red-900/40 rounded-lg border border-red-200 dark:border-red-800">
            <h2 className="font-bold text-gray-900 dark:text-white">Vulnerabilities</h2>
            <p className="text-sm text-gray-600 dark:text-gray-300">{vulnerabilities.length} found</p>
          </Link>
        </div>

        <div className="bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 mb-6 border border-gray-200 dark:border-neutral-700">
          <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">Service Health</h2>
          {loading ? (
            <p className="text-gray-600 dark:text-gray-300">Loading...</p>
          ) : (
            <div className="grid grid-cols-2 gap-4">
              {sboms.map((sbom: SBOM) => (
                <div key={sbom.service} className="p-4 border border-gray-200 dark:border-neutral-600 rounded bg-gray-50 dark:bg-neutral-700/50">
                  <h3 className="font-bold text-gray-900 dark:text-white">{sbom.service}</h3>
                  <p className="text-sm text-gray-600 dark:text-gray-300">Status: Healthy</p>
                  <p className="text-sm text-gray-600 dark:text-gray-300">Format: {sbom.format}</p>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700">
          <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">Recent Vulnerabilities</h2>
          {loading ? (
            <p className="text-gray-600 dark:text-gray-300">Loading...</p>
          ) : (
            <div className="space-y-2">
              {vulnerabilities.slice(0, 5).map((vuln: Vulnerability, idx: number) => (
                <div key={idx} className="p-4 border border-gray-200 dark:border-neutral-600 rounded flex items-center justify-between bg-gray-50 dark:bg-neutral-700/50">
                  <div>
                    <h3 className="font-bold text-gray-900 dark:text-white">{vuln.cve}</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-300">
                      {vuln.service} - {vuln.package}@{vuln.version}
                    </p>
                  </div>
                  <span className={`px-3 py-1 rounded text-white text-sm ${severityColors[vuln.severity] || 'bg-gray-600'}`}>
                    {vuln.severity}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </main>
  )
}

