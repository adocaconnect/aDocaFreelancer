import type { GetServerSideProps } from 'next'
import api from '../services/api'
import FreelancerCard from '../components/FreelancerCard'

export default function Home({ freelancers }: any) {
  return (
    <main className="max-w-6xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">Freelancers em destaque</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {freelancers.map((f: any) => (
          <FreelancerCard key={f.id} freelancer={f} />
        ))}
      </div>
    </main>
  )
}

export const getServerSideProps: GetServerSideProps = async () => {
  try {
    const res = await api.get('/freelancers?limit=9')
    return { props: { freelancers: res.data } }
  } catch (e) {
    return { props: { freelancers: [] } }
  }
}
