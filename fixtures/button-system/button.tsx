export type ButtonProps = {
  variant: "primary";
  disabled?: boolean;
  label: string;
};

export function Button({ variant, disabled = false, label }: ButtonProps) {
  const style = {
    background: "var(--color-action)",
    borderRadius: "var(--radius-button)",
  };

  return (
    <button data-variant={variant} disabled={disabled} style={style}>
      {label}
    </button>
  );
}
