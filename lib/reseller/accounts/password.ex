defmodule Reseller.Accounts.Password do
  @moduledoc false

  @algorithm :sha256
  @salt_length 16
  @derived_key_length 32

  def hash_password(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(@salt_length)
    iterations = password_hash_iterations()
    hash = derive(password, salt, iterations)

    Enum.join(
      [
        "pbkdf2_sha256",
        Integer.to_string(iterations),
        Base.url_encode64(salt, padding: false),
        Base.url_encode64(hash, padding: false)
      ],
      "$"
    )
  end

  def valid_password?(stored_hash, password)
      when is_binary(stored_hash) and is_binary(password) do
    with ["pbkdf2_sha256", iterations, salt, hash] <- String.split(stored_hash, "$", parts: 4),
         {iterations, ""} <- Integer.parse(iterations) do
      derived_hash = derive(password, Base.url_decode64!(salt, padding: false), iterations)
      expected_hash = Base.url_decode64!(hash, padding: false)

      Plug.Crypto.secure_compare(derived_hash, expected_hash)
    else
      _ -> false
    end
  end

  def valid_password?(_, _), do: false

  defp derive(password, salt, iterations) do
    :crypto.pbkdf2_hmac(@algorithm, password, salt, iterations, @derived_key_length)
  end

  defp password_hash_iterations do
    Application.get_env(:reseller, :password_hash_iterations, 100_000)
  end
end
