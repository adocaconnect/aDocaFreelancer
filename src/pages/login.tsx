import { useState } from 'react'
import { useRouter } from 'next/router'
import { useAuth } from '../hooks/useAuth'

export default function Login() {
  const router = useRouter()
  const { login } = useAuth() || {}
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: any) {
    e.preventDefault()
    setLoading(true)
    try {
      await login(email, password)
      router.push('/')
    } catch (err) {
      alert('Falha ao logar')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">Entrar</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <input type="email" value={email} onChange={(e)=>setEmail(e.target.value)} placeholder="email" className="w-full p-2 border rounded" />
        <input type="password" value={password} onChange={(e)=>setPassword(e.target.value)} placeholder="senha" className="w-full p-2 border rounded" />
        <button className="w-full p-2 bg-blue-600 text-white rounded" disabled={loading}>{loading? 'Entrando...' : 'Entrar'}</button>
      </form>
    </div>
  )
}
