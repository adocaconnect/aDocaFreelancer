import type { AppProps } from 'next/app'
import { AuthProvider } from '../hooks/useAuth'
import '../styles/globals.css'
import Header from '../components/Header'
import Footer from '../components/Footer'

export default function App({ Component, pageProps }: AppProps) {
  return (
    <AuthProvider>
      <Header />
      <main className="min-h-[70vh]">
        <Component {...pageProps} />
      </main>
      <Footer />
    </AuthProvider>
  )
}
