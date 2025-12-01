defmodule Basenji.Accounts.APIToken do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Basenji.Accounts.APIToken
  alias Basenji.Accounts.User

  @attrs [:token, :user_id]

  @hash_algorithm :sha256
  @rand_size 32

  schema "api_tokens" do
    field :token, :binary
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, @attrs)
    |> validate_changeset()
  end

  def build_api_token(user) do
    build_hashed_token(user)
  end

  defp validate_changeset(changeset) do
    changeset
    |> validate_required([:token, :user_id])
  end

  defp build_hashed_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %APIToken{
       token: hashed_token,
       user_id: user.id
     }}
  end

  def hash_algorithm, do: @hash_algorithm
end
