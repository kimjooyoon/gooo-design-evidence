export type ButtonContract = {
  actionToken: "color.action";
  controlSpaceToken: "space.control";
};

export function buttonContract(): ButtonContract {
  return {
    actionToken: "color.action",
    controlSpaceToken: "space.control",
  };
}
