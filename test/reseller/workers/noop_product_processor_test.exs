defmodule Reseller.Workers.NoopProductProcessorTest do
  use ExUnit.Case, async: true

  alias Reseller.Workers.NoopProductProcessor

  test "process/2 returns the placeholder awaiting_ai payload" do
    product = %{id: 42}

    assert {:ok,
            %{
              step: "awaiting_ai",
              payload: %{
                "message" => "Background processing foundation executed",
                "product_id" => 42
              }
            }} = NoopProductProcessor.process(product, [])
  end
end
