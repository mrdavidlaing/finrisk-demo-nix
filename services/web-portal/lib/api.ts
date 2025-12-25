import axios from 'axios'

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080'

export const api = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
  },
})

export interface TransferRequest {
  senderId: string
  recipientId: string
  amount: number
  currency: string
  rail: 'SWIFT' | 'CRYPTO'
}

export interface TransferResponse {
  id: string
  status: string
  fee: number
  totalAmount: number
  createdAt: string
}

export interface SBOM {
  service: string
  format: string
  path: string
}

export interface Vulnerability {
  service: string
  severity: string
  cve: string
  package: string
  version: string
}

export async function createTransfer(data: TransferRequest): Promise<TransferResponse> {
  const response = await api.post<TransferResponse>('/api/transfer', data)
  return response.data
}

export async function getTransfer(id: string): Promise<TransferResponse> {
  const response = await api.get<TransferResponse>(`/api/transfer/${id}`)
  return response.data
}

export async function listSBOMs(): Promise<SBOM[]> {
  const response = await api.get<SBOM[]>('/api/compliance/sboms')
  return response.data
}

export async function getSBOM(service: string): Promise<any> {
  const response = await api.get(`/api/compliance/sboms/${service}`)
  return response.data
}

export async function getVulnerabilities(): Promise<Vulnerability[]> {
  const response = await api.get<Vulnerability[]>('/api/compliance/vulnerabilities')
  return response.data
}


