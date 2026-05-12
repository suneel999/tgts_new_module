import { TrendingUp, TrendingDown } from "lucide-react";
import type { ElementType } from "react";
import clsx from "clsx";

type Props = {
  icon: ElementType;
  value: string | number;
  label: string;
  delta?: string;
  trend?: "up" | "down" | "flat";
};

export default function StatCard({ icon: Icon, value, label, delta = "", trend = "flat" }: Props) {
  return (
    <div className="bg-white rounded-lg shadow-card p-4">
      <div className="flex items-start justify-between">
        <div className="p-2 rounded-md bg-gray-100">
          <Icon className="w-5 h-5 text-gray-700" />
        </div>
        {delta && (
          <div
            className={clsx(
              "text-xs font-medium flex items-center gap-1",
              trend === "up" && "text-green-600",
              trend === "down" && "text-red-600",
              trend === "flat" && "text-gray-500"
            )}
          >
            {trend === "up" && <TrendingUp className="w-3 h-3" />}
            {trend === "down" && <TrendingDown className="w-3 h-3" />}
            {delta}
          </div>
        )}
      </div>
      <div className="mt-3 text-2xl font-semibold">{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}