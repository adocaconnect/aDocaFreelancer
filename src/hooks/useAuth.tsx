import { useState, useEffect, createContext, useContext, ReactNode } from 'react'
import jwtDecode from 'jwt-decode'
import api, { setAuthToken } from '../services/api'

type User = { id: string; name: string; email: string } | null

const AuthContext = createContext<any>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User>(null)
  const [token, setToken] = useState<string | null>(null)

  useEffect(() => {
    const t = typeof window !== 'undefined' ? localStorage.getItem('token') : null
    if (t) {
      setToken(t)
      setAuthToken(t)
      try {
        const decoded: any = jwtDecode(t)
        setUser({ id: decoded.sub, name: decoded.name, email: decoded.email })
      } catch (e) {
        setUser(null)
      }
    }
  }, [])

  async function login(email: string, password: string) {
    const res = await api.post('/auth/login', { email, password })
    const t = res.data.token
    if (typeof window !== 'undefined') localStorage.setItem('token', t)
    setToken(t)
    setAuthToken(t)
    const decoded: any = jwtDecode(t)
    setUser({ id: decoded.sub, name: decoded.name, email: decoded.email })
    return res
  }

  function logout() {
    if (typeof window !== 'undefined') localStorage.removeItem('token')
    setToken(null)
    setUser(null)
    setAuthToken(null)
  }

  return (
    <AuthContext.Provider value={{ user, token, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
