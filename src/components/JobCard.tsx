export default function JobCard({ job }: any) {
  return (
    <div className="p-4 bg-white rounded shadow">
      <h3 className="font-semibold">{job.title}</h3>
      <p className="text-sm text-gray-700 mt-2">{job.description}</p>
      <div className="mt-3 text-sm text-gray-600">Valor: {job.price}</div>
    </div>
  )
}
