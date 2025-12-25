'use client'

import React, { useEffect, useState } from 'react'
import { getVulnerabilities, Vulnerability } from '@/lib/api'
import Link from 'next/link'

export default function VulnerabilitiesPage() {
  const [vulnerabilities, setVulnerabilities] = useState<Vulnerability[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<string>('ALL')

  useEffect(() => {
    async function loadVulns() {
      try {
        const data = await getVulnerabilities()
        setVulnerabilities(data)
      } catch (err) {
        console.error('Failed to load vulnerabilities:', err)
      } finally {
        setLoading(false)
      }
    }
    loadVulns()
  }, [])

  const severityColors: Record<string, string> = {
    Critical: 'bg-red-600',
    High: 'bg-orange-600',
    Medium: 'bg-yellow-600',
    Low: 'bg-blue-600',
    Unknown: 'bg-gray-400'
  }

  // Normalize Grype severity casing (usually "High", "Medium") vs our internal use
  const normalizedSeverity = (sev: string): string => {
      // Capitalize first letter
      return sev.charAt(0).toUpperCase() + sev.slice(1).toLowerCase();
  }

  const filtered = filter === 'ALL' 
    ? vulnerabilities 
    : vulnerabilities.filter((v: Vulnerability) => normalizedSeverity(v.severity) === filter)

  // Count stats
  const stats = {
      Critical: vulnerabilities.filter((v: Vulnerability) => normalizedSeverity(v.severity) === 'Critical').length,
      High: vulnerabilities.filter((v: Vulnerability) => normalizedSeverity(v.severity) === 'High').length,
      Medium: vulnerabilities.filter((v: Vulnerability) => normalizedSeverity(v.severity) === 'Medium').length,
      Low: vulnerabilities.filter((v: Vulnerability) => normalizedSeverity(v.severity) === 'Low').length,
  }

  return (
    <main className="flex min-h-screen flex-col p-24">
      <div className="z-10 max-w-6xl w-full">
        <Link href="/admin" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Admin
        </Link>
        <h1 className="text-4xl font-bold mb-8 text-gray-900 dark:text-white">Vulnerability Report</h1>
        
        <p className="mb-4 text-gray-600 dark:text-gray-300">
           Scanning results from Grype. Run <code className="bg-gray-100 dark:bg-neutral-700 px-2 py-1 rounded text-gray-800 dark:text-gray-200">nix run .#scan-all</code> to update.
        </p>

        <div className="mb-6 flex gap-2 flex-wrap">
          <button
            onClick={() => setFilter('ALL')}
            className={`px-4 py-2 rounded transition-colors ${filter === 'ALL' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-neutral-700 text-gray-800 dark:text-gray-200'}`}
          >
            All ({vulnerabilities.length})
          </button>
          <button
            onClick={() => setFilter('Critical')}
            className={`px-4 py-2 rounded transition-colors ${filter === 'Critical' ? 'bg-red-600 text-white' : 'bg-gray-200 dark:bg-neutral-700 text-gray-800 dark:text-gray-200'}`}
          >
            Critical ({stats.Critical})
          </button>
          <button
            onClick={() => setFilter('High')}
            className={`px-4 py-2 rounded transition-colors ${filter === 'High' ? 'bg-orange-600 text-white' : 'bg-gray-200 dark:bg-neutral-700 text-gray-800 dark:text-gray-200'}`}
          >
            High ({stats.High})
          </button>
          <button
            onClick={() => setFilter('Medium')}
            className={`px-4 py-2 rounded transition-colors ${filter === 'Medium' ? 'bg-yellow-600 text-white' : 'bg-gray-200 dark:bg-neutral-700 text-gray-800 dark:text-gray-200'}`}
          >
            Medium ({stats.Medium})
          </button>
        </div>

        {loading ? (
          <p className="text-gray-600 dark:text-gray-300">Loading vulnerabilities...</p>
        ) : (
          <div className="space-y-4">
            {filtered.length === 0 ? (
                <p className="text-gray-500 dark:text-gray-400 italic">No vulnerabilities found matching this filter.</p>
            ) : (
                filtered.map((vuln: Vulnerability, idx: number) => (
                <div key={idx} className="bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700 border-l-4" style={{ borderLeftColor: severityColors[normalizedSeverity(vuln.severity)]?.replace('bg-', '') || 'gray' }}>
                    <div className="flex items-center justify-between mb-2">
                    <h2 className="text-xl font-bold text-gray-900 dark:text-white">{vuln.cve}</h2>
                    <span className={`px-3 py-1 rounded text-white text-sm ${severityColors[normalizedSeverity(vuln.severity)] || 'bg-gray-600'}`}>
                        {normalizedSeverity(vuln.severity)}
                    </span>
                    </div>
                    <p className="text-gray-600 dark:text-gray-300 mb-2">
                    <strong className="text-gray-900 dark:text-white">Service:</strong> {vuln.service}
                    </p>
                    <p className="text-gray-600 dark:text-gray-300 mb-2">
                    <strong className="text-gray-900 dark:text-white">Package:</strong> {vuln.package}@{vuln.version}
                    </p>
                    <a
                    href={`https://nvd.nist.gov/vuln/detail/${vuln.cve}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-500 dark:text-blue-400 hover:underline"
                    >
                    View on NVD →
                    </a>
                </div>
                ))
            )}
          </div>
        )}
      </div>
    </main>
  )
}
