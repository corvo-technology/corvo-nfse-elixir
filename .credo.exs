%{
  configs: [
    %{
      name: "default",
      checks: %{
        disabled: [
          # CorvoNfse.Types.Invoice mirrors the NFS-e invoice wire contract,
          # which mandates 33 fields. Removing fields would change the public
          # API, so the "structs with 32+ fields" VM heuristic does not apply
          # to this SDK.
          {Credo.Check.Warning.StructFieldAmount, []}
        ]
      }
    }
  ]
}
