import { GetServerSideProps } from 'next'
import api from '../../services/api'

export default function FreelancerPage({ freelancer }: any) {
  if (!freelancer) return <div className="p-6">Perfil não encontrado</div>
  return (
    <div className="max-w-4xl mx-auto p-6 bg-white rounded shadow mt-6">
      <div className="flex items-center gap-6">
        <img src={freelancer.avatar || '/favicon.ico'} alt="avatar" className="w-24 h-24 rounded-full" />
        <div>
          <h1 className="text-2xl font-bold">{freelancer.name}</h1>
          <p className="text-sm text-gray-600">{freelancer.title}</p>
        </div>
      </div>
      <section className="mt-6">
        <h2 className="font-semibold">Sobre</h2>
        <p className="mt-2 text-gray-700">{freelancer.bio}</p>
      </section>
    </div>
  )
}

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  const { id } = ctx.params as any
  try {
    const res = await api.get(`/freelancers/${id}`)
    return { props: { freelancer: res.data } }
  } catch (e) {
    return { props: { freelancer: null } }
  }
}
