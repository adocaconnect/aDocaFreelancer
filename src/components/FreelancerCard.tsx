import Link from 'next/link'

export default function FreelancerCard({ freelancer }: any) {
  return (
    <div className="p-4 bg-white rounded shadow">
      <div className="flex items-center gap-4">
        <img src={freelancer.avatar || '/favicon.ico'} alt="avatar" className="w-16 h-16 rounded-full" />
        <div>
          <h3 className="font-semibold">{freelancer.name}</h3>
          <p className="text-sm text-gray-600">{freelancer.title}</p>
        </div>
      </div>
      <p className="mt-3 text-sm text-gray-700">{freelancer.bio}</p>
      <div className="mt-3">
        <Link href={`/freelancers/${freelancer.id}`}><a className="text-sm text-blue-600">Ver perfil</a></Link>
      </div>
    </div>
  )
}
