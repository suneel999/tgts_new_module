type Props = {
  title: string;
  children: React.ReactNode;
};

export default function SectionCard({ title, children }: Props) {
  return (
    <div className="bg-white rounded-lg shadow-card p-4">
      <div className="font-medium mb-3">{title}</div>
      {children}
    </div>
  );
}