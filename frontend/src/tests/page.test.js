import { render, screen } from "@testing-library/react";
import Home from "../app/page";

// Mock the components that might have dependencies
jest.mock("../context/CartContext", () => ({
  CartProvider: ({ children }) => <div>{children}</div>,
  useCart: () => ({
    cart: [],
    addToCart: jest.fn(),
    removeFromCart: jest.fn(),
    clearCart: jest.fn(),
  }),
}));

describe("Home", () => {
  it("renders without crashing", () => {
    render(<Home />);
    // This test will pass as long as the component renders without throwing
    expect(true).toBe(true);
  });
});
