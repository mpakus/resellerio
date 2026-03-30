defmodule Reseller.ReleaseTest do
  use Reseller.DataCase, async: false

  test "migrate/0 runs successfully for configured repos" do
    assert is_list(Reseller.Release.migrate())
  end
end
