defmodule Basenji.Factory.AccountsFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def user_factory(attrs) do
        password = Map.get(attrs, :password, Faker.Internet.slug())
        hashed = if password, do: Bcrypt.hash_pwd_salt(password)

        %Basenji.Accounts.User{
          email: Faker.Internet.email(),
          password: password,
          hashed_password: hashed,
          confirmed_at: Faker.DateTime.backward(1)
        }
        |> merge_attributes(attrs)
        |> evaluate_lazy_attributes()
      end
    end
  end
end
