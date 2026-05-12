type Props = { title: string };
export default function PagePlaceholder({ title }: Props) {
  return (
    <div className="bg-white rounded-lg shadow-card p-8 text-gray-600">
      <div className="text-lg font-semibold mb-2">{title}</div>
      <div className="text-sm">This section will be implemented with APIs later.</div>
    </div>
  );
}