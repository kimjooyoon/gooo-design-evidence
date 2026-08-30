export type ButtonProps = {
  tone: "brand";
  disabled?: boolean;
  label: string;
};

export function Button({ tone, disabled = false, label }: ButtonProps) {
  const style = {
    background: "var(--color-action)",
    padding: "var(--space-control)",
  };

  return (
    <button data-tone={tone} disabled={disabled} style={style}>
      {label}
    </button>
  );
}
