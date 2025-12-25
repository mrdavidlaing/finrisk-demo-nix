'use client'

import React, { useEffect, useState } from 'react'
import { listSBOMs, getSBOM, SBOM } from '@/lib/api'
import Link from 'next/link'

interface Component {
  name: string
  version: string
  type: string
  purl?: string
}

interface SBOMData {
  bomFormat: string
  specVersion: string
  components: Component[]
}

export default function SBOMsPage() {
  const [sboms, setSboms] = useState<SBOM[]>([])
  const [selectedService, setSelectedService] = useState<string | null>(null)
  const [sbomData, setSbomData] = useState<SBOMData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadSBOMs() {
      try {
        const data = await listSBOMs()
        setSboms(data)
      } catch (err) {
        console.error('Failed to load SBOMs:', err)
      } finally {
        setLoading(false)
      }
    }
    loadSBOMs()
  }, [])

  const viewSBOM = async (service: string) => {
    setSelectedService(service)
    setSbomData(null)
    try {
      const data = await getSBOM(service)
      setSbomData(data)
    } catch (err) {
      console.error('Failed to load SBOM detail:', err)
    }
  }

  return (
    <main className="flex min-h-screen flex-col p-24">
      <div className="z-10 max-w-6xl w-full">
        <Link href="/admin" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Admin
        </Link>
        <h1 className="text-4xl font-bold mb-8 text-gray-900 dark:text-white">SBOM Viewer</h1>

        {loading ? (
          <p className="text-gray-600 dark:text-gray-300">Loading SBOMs...</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* List of SBOMs */}
            <div className="col-span-1 space-y-4">
              <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">Services</h2>
              {sboms.length === 0 ? (
                 <p className="text-gray-500 dark:text-gray-400 italic">No SBOMs found. Run `nix run .#scan-all` to generate them.</p>
              ) : (
                sboms.map((sbom: SBOM) => (
                  <div 
                    key={sbom.service} 
                    className={`p-4 border rounded cursor-pointer transition-colors ${
                      selectedService === sbom.service 
                        ? 'bg-blue-50 dark:bg-blue-900/40 border-blue-500 dark:border-blue-400' 
                        : 'bg-white dark:bg-neutral-800 border-gray-200 dark:border-neutral-700 hover:bg-gray-50 dark:hover:bg-neutral-700'
                    }`}
                    onClick={() => viewSBOM(sbom.service)}
                  >
                    <h3 className="font-bold text-gray-900 dark:text-white">{sbom.service}</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-300">Format: {sbom.format}</p>
                  </div>
                ))
              )}
            </div>

            {/* SBOM Detail */}
            <div className="col-span-2 bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 min-h-[500px] border border-gray-200 dark:border-neutral-700">
              {selectedService ? (
                <>
                  <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">{selectedService} Components</h2>
                  {sbomData ? (
                    <div className="overflow-x-auto">
                      <table className="min-w-full text-sm">
                        <thead className="bg-gray-100 dark:bg-neutral-700">
                          <tr>
                            <th className="px-4 py-2 text-left text-gray-900 dark:text-white">Name</th>
                            <th className="px-4 py-2 text-left text-gray-900 dark:text-white">Version</th>
                            <th className="px-4 py-2 text-left text-gray-900 dark:text-white">Type</th>
                          </tr>
                        </thead>
                        <tbody>
                          {sbomData.components?.map((comp: Component, i: number) => (
                            <tr key={i} className="border-b border-gray-200 dark:border-neutral-600 hover:bg-gray-50 dark:hover:bg-neutral-700/50">
                              <td className="px-4 py-2 font-medium text-gray-900 dark:text-white">{comp.name}</td>
                              <td className="px-4 py-2 text-gray-600 dark:text-gray-300">{comp.version}</td>
                              <td className="px-4 py-2 text-gray-500 dark:text-gray-400">{comp.type}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                      <div className="mt-4 text-xs text-gray-400 dark:text-gray-500">
                        Total components: {sbomData.components?.length || 0}
                      </div>
                    </div>
                  ) : (
                    <p className="text-gray-600 dark:text-gray-300">Loading details...</p>
                  )}
                </>
              ) : (
                <div className="flex items-center justify-center h-full text-gray-400 dark:text-gray-500">
                  Select a service to view its SBOM
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </main>
  )
}
