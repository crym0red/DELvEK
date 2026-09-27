# DELvEK framework embedding fix

The `LiveContainer` target's existing `Embed Frameworks` build phase already
contained `LiveContainerShared.framework`, but the phase was configured with
`runOnlyForDeploymentPostprocessing = 1`. That prevented the framework from
being copied into the normal `build` product used by the unsigned IPA job.

The phase is now enabled for normal builds (`runOnlyForDeploymentPostprocessing = 0`).
Its existing framework entries and target dependency are unchanged.
