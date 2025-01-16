# Supabase Storage

[Storage](https://supabase.com/docs/guides/storage) implementation for the [Supabase Potion](https://hexdocs.pm/supabase_potion) SDK in Elixir.

## Installation

```elixir
def deps do
  [
    {:supabase_potion, "~> 0.6"},
    {:supabase_storage, "~> 0.4"}
  ]
end
```

## Usage

Firstly you need to initialize your Supabase client(s) as can be found on the [Supabase Potion documentation](https://hexdocs.pm/supabase_potion/readme.html#usage)

Now you can pass the Client to the `Supabase.Storage` functions:

```elixir
iex> Supabase.Storage.list_buckets(%Supabase.Client{})
```
