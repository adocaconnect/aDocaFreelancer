import Link from 'next/link'
import { useAuth } from '../hooks/useAuth'

export default function Header() {
  const { user, logout } = useAuth() || {}
  return (
    <header className="bg-white shadow">
      <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
        <Link href="/">
          <a className="font-bold text-xl">aDocaFreelancer</a>
        </Link>
        <nav className="space-x-4">
          <Link href="/jobs"><a>Vagas</a></Link>
          <Link href="/freelancers"><a>Freelancers</a></Link>
          {user ? (
            <>
              <span>{user.name}</span>
              <button onClick={logout} className="ml-2">Sair</button>
            </>
          ) : (
            <>
              <Link href="/login"><a>Entrar</a></Link>
            </>
          )}
        </nav>
      </div>
    </header>
  )
}
