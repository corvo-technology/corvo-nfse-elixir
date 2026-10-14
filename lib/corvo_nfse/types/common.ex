defmodule CorvoNfse.Types.Common do
  @moduledoc """
  Shared wire types.

  ## Envelopes

  Every JSON success is `{data: ...}`. Lists add a pagination object:

      {data: T[], pagination: {limit, hasMore, nextCursor}}

  `nextCursor` is an opaque base64url cursor and is `null` when `hasMore` is
  `false`. Server field names are never re-cased.

  ## Maps vs structs

  The SDK returns plain maps with **string keys** exactly as the server sent
  them; response structs such as `CorvoNfse.Types.Company` mirror the same
  fields for documentation, construction and typed wrappers.
  """

  @type pagination :: %{
          required("limit") => integer(),
          required("hasMore") => boolean(),
          required("nextCursor") => String.t() | nil
        }

  @typedoc "A list page as returned by every `list`/`iterate` operation."
  @type page :: %{data: [map()], pagination: pagination() | nil}

  @type environment :: "test" | "live"
end
