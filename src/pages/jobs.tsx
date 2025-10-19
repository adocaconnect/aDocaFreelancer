import api from '../services/api'
import JobCard from '../components/JobCard'

export default function Jobs({ jobs }: any) {
  return (
    <div className="max-w-6xl mx-auto p-6">
      <h1 className="text-2xl font-bold">Vagas</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
        {jobs.map((j: any) => <JobCard key={j.id} job={j} />)}
      </div>
    </div>
  )
}

export async function getServerSideProps() {
  try {
    const res = await api.get('/jobs')
    return { props: { jobs: res.data } }
  } catch (e) {
    return { props: { jobs: [] } }
  }
}
