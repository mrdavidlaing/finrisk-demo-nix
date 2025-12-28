'use client'

import React, { useState } from 'react'
import { runSmokeTests, SmokeTestResponse, CucumberFeature, CucumberScenario, CucumberStep } from '@/lib/api'
import Link from 'next/link'

export default function SmokeTestsPage() {
  const [results, setResults] = useState<SmokeTestResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [expandedFeatures, setExpandedFeatures] = useState<Set<string>>(new Set())
  const [expandedScenarios, setExpandedScenarios] = useState<Set<string>>(new Set())

  const handleRunTests = async () => {
    setLoading(true)
    setError(null)
    setResults(null)
    try {
      const data = await runSmokeTests()
      setResults(data)
      // Auto-expand all features
      setExpandedFeatures(new Set(data.features.map(f => f.name)))
    } catch (err: any) {
      setError(err.message || 'Failed to run smoke tests')
    } finally {
      setLoading(false)
    }
  }

  const toggleFeature = (featureName: string) => {
    const newExpanded = new Set(expandedFeatures)
    if (newExpanded.has(featureName)) {
      newExpanded.delete(featureName)
    } else {
      newExpanded.add(featureName)
    }
    setExpandedFeatures(newExpanded)
  }

  const toggleScenario = (scenarioKey: string) => {
    const newExpanded = new Set(expandedScenarios)
    if (newExpanded.has(scenarioKey)) {
      newExpanded.delete(scenarioKey)
    } else {
      newExpanded.add(scenarioKey)
    }
    setExpandedScenarios(newExpanded)
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'passed':
        return <span className="text-green-600 dark:text-green-400">✓</span>
      case 'failed':
        return <span className="text-red-600 dark:text-red-400">✗</span>
      case 'pending':
        return <span className="text-gray-400">○</span>
      default:
        return <span className="text-gray-400">○</span>
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'passed':
        return 'text-green-600 dark:text-green-400'
      case 'failed':
        return 'text-red-600 dark:text-red-400'
      case 'pending':
        return 'text-gray-400'
      default:
        return 'text-gray-400'
    }
  }

  const formatDuration = (seconds: number) => {
    if (seconds < 1) {
      return `${(seconds * 1000).toFixed(0)}ms`
    }
    return `${seconds.toFixed(2)}s`
  }

  return (
    <main className="flex min-h-screen flex-col p-24">
      <div className="z-10 max-w-6xl w-full">
        <Link href="/admin" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Admin
        </Link>
        
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white">Smoke Tests</h1>
          <button
            onClick={handleRunTests}
            disabled={loading}
            className="px-6 py-3 bg-purple-600 hover:bg-purple-700 disabled:bg-purple-400 text-white rounded-lg font-semibold transition-colors flex items-center gap-2"
          >
            {loading ? (
              <>
                <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Running...
              </>
            ) : (
              'Run Tests'
            )}
          </button>
        </div>

        {error && (
          <div className="bg-red-100 dark:bg-red-900/40 border border-red-400 dark:border-red-800 text-red-700 dark:text-red-300 px-4 py-3 rounded mb-6">
            <strong>Error:</strong> {error}
          </div>
        )}

        {results && (
          <>
            {/* Summary Bar */}
            <div className="bg-white dark:bg-neutral-800 p-6 rounded-lg shadow dark:shadow-neutral-900/50 mb-6 border border-gray-200 dark:border-neutral-700">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Test Summary</h2>
                <div className="text-sm text-gray-600 dark:text-gray-300">
                  Total duration: {formatDuration(results.duration)}
                </div>
              </div>
              <div className="flex gap-4">
                <div className="flex items-center gap-2">
                  <span className="text-green-600 dark:text-green-400 font-bold text-xl">✓</span>
                  <span className="text-gray-900 dark:text-white font-semibold">{results.summary.passed}</span>
                  <span className="text-gray-600 dark:text-gray-300">passed</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-red-600 dark:text-red-400 font-bold text-xl">✗</span>
                  <span className="text-gray-900 dark:text-white font-semibold">{results.summary.failed}</span>
                  <span className="text-gray-600 dark:text-gray-300">failed</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-gray-400 font-bold text-xl">○</span>
                  <span className="text-gray-900 dark:text-white font-semibold">{results.summary.pending}</span>
                  <span className="text-gray-600 dark:text-gray-300">pending</span>
                </div>
                <div className="flex items-center gap-2 ml-auto">
                  <span className="text-gray-900 dark:text-white font-semibold">Total:</span>
                  <span className="text-gray-600 dark:text-gray-300">{results.summary.total}</span>
                </div>
              </div>
            </div>

            {/* Features */}
            <div className="space-y-4">
              {results.features.map((feature: CucumberFeature, featureIdx: number) => {
                const isExpanded = expandedFeatures.has(feature.name)
                return (
                  <div
                    key={featureIdx}
                    className="bg-white dark:bg-neutral-800 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700"
                  >
                    <button
                      onClick={() => toggleFeature(feature.name)}
                      className="w-full text-left p-6 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-neutral-700/50 transition-colors"
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-gray-400">{isExpanded ? '▼' : '▶'}</span>
                        <h3 className="text-xl font-bold text-gray-900 dark:text-white">{feature.name}</h3>
                      </div>
                      <div className="text-sm text-gray-600 dark:text-gray-300">
                        {feature.scenarios.length} scenario{feature.scenarios.length !== 1 ? 's' : ''}
                      </div>
                    </button>

                    {isExpanded && (
                      <div className="px-6 pb-6 border-t border-gray-200 dark:border-neutral-700">
                        {feature.description && (
                          <p className="mt-4 mb-4 text-gray-600 dark:text-gray-300 italic">{feature.description}</p>
                        )}

                        <div className="space-y-3 mt-4">
                          {feature.scenarios.map((scenario: CucumberScenario, scenarioIdx: number) => {
                            const scenarioKey = `${feature.name}-${scenario.name}`
                            const isScenarioExpanded = expandedScenarios.has(scenarioKey)
                            return (
                              <div
                                key={scenarioIdx}
                                className="border border-gray-200 dark:border-neutral-600 rounded bg-gray-50 dark:bg-neutral-700/50"
                              >
                                <button
                                  onClick={() => toggleScenario(scenarioKey)}
                                  className="w-full text-left p-4 flex items-center justify-between hover:bg-gray-100 dark:hover:bg-neutral-600 transition-colors"
                                >
                                  <div className="flex items-center gap-3">
                                    <span className="text-gray-400 text-sm">{isScenarioExpanded ? '▼' : '▶'}</span>
                                    {getStatusIcon(scenario.status)}
                                    <span className="font-semibold text-gray-900 dark:text-white">{scenario.name}</span>
                                  </div>
                                  <div className="text-sm text-gray-600 dark:text-gray-300">
                                    {formatDuration(scenario.duration)}
                                  </div>
                                </button>

                                {isScenarioExpanded && (
                                  <div className="px-4 pb-4 border-t border-gray-200 dark:border-neutral-600">
                                    <div className="mt-3 space-y-2">
                                      {scenario.steps.map((step: CucumberStep, stepIdx: number) => (
                                        <div
                                          key={stepIdx}
                                          className="flex items-start gap-3 text-sm"
                                        >
                                          <div className="w-16 text-right">
                                            <span className={`font-mono font-semibold ${getStatusColor(step.status)}`}>
                                              {step.keyword}
                                            </span>
                                          </div>
                                          <div className="flex-1">
                                            <div className="flex items-center gap-2">
                                              <span className={getStatusColor(step.status)}>
                                                {getStatusIcon(step.status)}
                                              </span>
                                              <span className="text-gray-700 dark:text-gray-300">{step.text}</span>
                                              <span className="text-gray-500 dark:text-gray-400 text-xs ml-auto">
                                                {formatDuration(step.duration)}
                                              </span>
                                            </div>
                                            {step.error && (
                                              <div className="mt-2 ml-6 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded text-red-700 dark:text-red-300 text-xs font-mono">
                                                {step.error}
                                              </div>
                                            )}
                                          </div>
                                        </div>
                                      ))}
                                    </div>
                                  </div>
                                )}
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </>
        )}

        {!results && !loading && !error && (
          <div className="bg-white dark:bg-neutral-800 p-12 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700 text-center">
            <p className="text-gray-600 dark:text-gray-300 mb-4">
              Click "Run Tests" to execute the smoke test suite and validate the transfer flow across all microservices.
            </p>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Tests will validate service health, successful transfers (SWIFT and CRYPTO), and error scenarios (KYC failures, sanctions screening).
            </p>
          </div>
        )}
      </div>
    </main>
  )
}


