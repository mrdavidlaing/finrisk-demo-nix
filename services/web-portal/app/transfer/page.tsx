'use client'

import React, { useState, FormEvent, ChangeEvent } from 'react'
import { createTransfer, TransferRequest, TransferResponse } from '@/lib/api'
import Link from 'next/link'

export default function TransferPage() {
  const [formData, setFormData] = useState<TransferRequest>({
    senderId: '',
    recipientId: '',
    amount: 0,
    currency: 'USD',
    rail: 'SWIFT',
  })
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<TransferResponse | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const response = await createTransfer(formData)
      setResult(response)
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Transfer failed'
      setError(errorMessage)
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="flex min-h-screen flex-col items-center p-24">
      <div className="z-10 max-w-2xl w-full">
        <Link href="/" className="text-blue-500 dark:text-blue-400 hover:underline mb-4 inline-block">
          ← Back to Home
        </Link>
        <h1 className="text-4xl font-bold mb-8 text-gray-900 dark:text-white">Initiate Transfer</h1>

        <form onSubmit={handleSubmit} className="space-y-6 bg-white dark:bg-neutral-800 p-8 rounded-lg shadow dark:shadow-neutral-900/50 border border-gray-200 dark:border-neutral-700">
          <div>
            <label className="block text-sm font-medium mb-2 text-gray-700 dark:text-gray-200">Sender ID</label>
            <input
              type="text"
              value={formData.senderId}
              onChange={(e: ChangeEvent<HTMLInputElement>) => setFormData({ ...formData, senderId: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-neutral-600 rounded-md bg-white dark:bg-neutral-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-700 dark:text-gray-200">Recipient ID</label>
            <input
              type="text"
              value={formData.recipientId}
              onChange={(e: ChangeEvent<HTMLInputElement>) => setFormData({ ...formData, recipientId: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-neutral-600 rounded-md bg-white dark:bg-neutral-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-700 dark:text-gray-200">Amount</label>
            <input
              type="number"
              step="0.01"
              value={formData.amount}
              onChange={(e: ChangeEvent<HTMLInputElement>) => setFormData({ ...formData, amount: parseFloat(e.target.value) })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-neutral-600 rounded-md bg-white dark:bg-neutral-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-700 dark:text-gray-200">Currency</label>
            <select
              value={formData.currency}
              onChange={(e: ChangeEvent<HTMLSelectElement>) => setFormData({ ...formData, currency: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-neutral-600 rounded-md bg-white dark:bg-neutral-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="USD">USD</option>
              <option value="EUR">EUR</option>
              <option value="GBP">GBP</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-2 text-gray-700 dark:text-gray-200">Transfer Rail</label>
            <select
              value={formData.rail}
              onChange={(e: ChangeEvent<HTMLSelectElement>) => setFormData({ ...formData, rail: e.target.value as 'SWIFT' | 'CRYPTO' })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-neutral-600 rounded-md bg-white dark:bg-neutral-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="SWIFT">SWIFT (Bank Transfer)</option>
              <option value="CRYPTO">Crypto (Blockchain)</option>
            </select>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded-md disabled:opacity-50 transition-colors"
          >
            {loading ? 'Processing...' : 'Initiate Transfer'}
          </button>
        </form>

        {error && (
          <div className="mt-6 p-4 bg-red-100 dark:bg-red-900/40 border border-red-400 dark:border-red-700 text-red-700 dark:text-red-300 rounded">
            Error: {error}
          </div>
        )}

        {result && (
          <div className="mt-6 p-4 bg-green-100 dark:bg-green-900/40 border border-green-400 dark:border-green-700 text-green-700 dark:text-green-300 rounded">
            <h3 className="font-bold mb-2">Transfer Initiated</h3>
            <p>Transfer ID: {result.id}</p>
            <p>Status: {result.status}</p>
            <p>Fee: ${result.fee}</p>
            <p>Total Amount: ${result.totalAmount}</p>
          </div>
        )}
      </div>
    </main>
  )
}

