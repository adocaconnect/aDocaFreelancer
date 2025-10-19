import Link from 'next/link'
import api from '../../services/api'
import FreelancerCard from '../../components/FreelancerCard'

export default function Freelancers({ freelancers }: any) {
  return (
    <div className="max-w-6xl mx-auto p-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Freelancers</h1>
        <Link href="/"><a className="text-sm text-blue-600">Voltar</a></Link>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
        {freelancers.map((f: any) => <FreelancerCard key={f.id} freelancer={f} />)}
      </div>
    </div>
  )
}

export async function getServerSideProps() {
  try {
    const res = await api.get('/freelancers')
    return { props: { freelancers: res.data } }
  } catch (e) {
    return { props: { freelancers: [] } }
  }
}
